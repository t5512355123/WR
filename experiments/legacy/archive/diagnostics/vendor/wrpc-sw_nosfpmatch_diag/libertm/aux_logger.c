/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Copyright 2020-2021 CERN
 * Author: Juan David Gonzalez Cobas
 *
 * This program calls the library libertm to control an eRTM14/15 combo
 */

#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h>

#include "libertm.h"
#include "private.h"
#include "display.h"
#include "spll_debug.h"

static int32_t signext32(uint32_t in, int bit)
{
	uint32_t mask = ~((1 << bit) - 1);
	if (in & (1 << bit))
		return in | mask;
	else
		return in;
}



static const char *dbg_source_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_SRC_HELPER:
		return "helper";
	case SPLL_DBG_SRC_MAIN:
		return "main";
	case SPLL_DBG_SRC_AUX(0):
		return "aux0";
	case SPLL_DBG_SRC_AUX(1):
		return "aux1";
	case SPLL_DBG_SRC_AUX(2):
		return "aux2";
	case SPLL_DBG_SRC_AUX(3):
		return "aux3";
	case SPLL_DBG_SRC_EXT:
		return "ext";
	default:
		return "<unknown?>";
	}
}

static const char *dbg_signal_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_SIGNAL_ERR:
		return "err";
	case SPLL_DBG_SIGNAL_Y:
		return "y";
	case SPLL_DBG_SIGNAL_PERIOD:
		return "period";
	case SPLL_DBG_SIGNAL_REF:
		return "ref";
	case SPLL_DBG_SIGNAL_TAG:
		return "tag";
	case SPLL_DBG_SIGNAL_SAMPLE_ID:
		return "sample";
	case SPLL_DBG_SIGNAL_TIME_MS:
		return "time_ms";
	case SPLL_DBG_SIGNAL_PHASE_CURRENT:
		return "phase_current";
	case SPLL_DBG_SIGNAL_PHASE_TARGET:
		return "phase_target";
	default:
		return "<unknown?>";
	}
}

static const char *dbg_event_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_EVT_GAIN_SWITCH:
		return "gain-switch";
	case SPLL_DBG_EVT_LOCK_ACQUIRED:
		return "lock-acquired";
	case SPLL_DBG_EVT_LOCK_LOSS:
		return "lock-lost";
	case SPLL_DBG_EVT_START:
		return "start";
	default:
		return "<unknown?>";
	}
}


static int prev_src = -1;

int n_samples = 3000;
int total_samples = 0;

int spll_dump_debug_data(FILE *f_out, const uint32_t *buf, size_t size)
{
	while (size--)
	{
		uint32_t x = *buf++;

		int sig = SPLL_DBG_EXTRACT_SIGNAL(x);
		int src = SPLL_DBG_EXTRACT_SOURCE(x);
		uint32_t value_raw = SPLL_DBG_EXTRACT_VALUE(x);
		int32_t value;

		switch (sig)
		{
		case SPLL_DBG_SIGNAL_ERR:
			value = signext32(value_raw, 23);
			break;
		default:
			value = value_raw;
		};

		if (prev_src != src)
		{
			fprintf(f_out, "%s ", dbg_source_to_string(src));
			prev_src = src;
		}

		if (sig == SPLL_DBG_SIGNAL_EVENT)
		{
			fprintf(f_out, " event=%s", dbg_event_to_string(value));
		}

		fprintf(f_out, "%s=%d ", dbg_signal_to_string(sig),
			   value);

		if (SPLL_DBG_IS_LAST_RECORD(x))
		{
			fprintf(f_out, "\n");
			prev_src = -1;
			total_samples++;
			if(total_samples > n_samples)
				return -1;
		}
	}

	return 0;
}



void spll_readout_ertm14( struct ertm_status *handle, FILE* f_out, int undersample )
{

	int r = ertm_configure_spll_debug_dump(handle, 1, undersample);
	if (r)
		perror("ertm_configure_spll_debug_dump()");

	for (;;)
	{
		uint32_t buf[16384];
		size_t buf_size = 16384;
		int r = ertm_read_spll_debug_data(handle, buf, &buf_size);
		if (r >= 0)
		{
			//printf("read %llu\n", buf_size);
			if( spll_dump_debug_data(f_out, buf, buf_size) < 0)
				break;
		}
	}

	int retries=3;

	while(retries > 0)
	{
		r = ertm_configure_spll_debug_dump( handle, 0, 0 );
		if (r)
		{
			perror("ertm_configure_spll_debug_dump(), retrying");
			sleep(1);
			retries--;
		}
		else
		{
			break;
		}
	}

	fprintf(stderr, "ertm14: stopping SPLL logging...\n");
}

void linspace( double start, double stop, int n, double *out )
{
	int i;
	for(i=0;i<n;i++)
	{
		out[i] = start + (stop-start) * (double) i / (double) n;
		printf("%d: %.0f\n",i,out[i]);
	}
}

int wait_wdiag_bits( struct ertm_status *handle, uint32_t mask, int timeout_secs )
{
	for(;;)
	{
		if( ertm_wr_diags(handle, &handle->state->wr_status) < 0 )
		{
			fprintf(stderr,"Failed to read wdiags. retrying.\n");
			usleep(300000);
			continue;
		}

		uint32_t value = handle->state->wr_status.WDIAG_PSTAT & mask;

		printf("mask: %x masked %x\n", mask, value);

		if(value)
			break;

		sleep(1);
		timeout_secs--;
		if(!timeout_secs)
			return -ETIMEDOUT;
	}

	return 0;
}

int main(void)
{
	static char usb[] = "/dev/ttyUSB2";
	struct ertm_status *handle = ertm_init(NULL);

	const int n_ki_gains = 10;
	const int n_kp_gains = 10;
	double kp_gains[n_kp_gains];
	double ki_gains[n_ki_gains];

	linspace(2000, 4000 * 16, n_kp_gains, kp_gains );
	linspace(10, 200, n_ki_gains, ki_gains );
	
	if (handle == NULL) {
		fprintf(stderr, "could not open %s\n", usb);
		exit(1);
	}

	ertm_configure_spll_debug_dump(handle, 0, 0);

		
	if( wait_wdiag_bits( handle, WRC_DIAGS_WDIAG_PSTAT_LINK, 100 ) < 0 )
	{
		printf("Link up timeout...\n");
		return -1;
	}

	ertm_execute_shell_command( handle, "ptp stop");
	usleep(100000);


	int ii, pp;

	for(ii=0;ii<n_ki_gains;ii++)
	{
	for(pp=0;pp<n_kp_gains;pp++)
	{
		char cmd[64],fname[64];
		printf("Try kp=%f,ki=%f\n", -kp_gains[pp], -ki_gains[ii] );
		sprintf(cmd,"pll gain 0 0 %f %f\n", -kp_gains[pp], -ki_gains[ii] );
		ertm_execute_shell_command( handle, cmd);
		usleep(100000);
		ertm_execute_shell_command( handle, "pll init 4 0 0");
		sleep(2);
		ertm_execute_shell_command( handle, "pll init 3 0 0");
		sleep(2);

		if( wait_wdiag_bits( handle, WRC_DIAGS_WDIAG_PSTAT_LOCKED, 20 ) < 0 )
		{
			printf("PLL lock timeout.\n");
			continue;
		}

		total_samples = 0;
		sprintf(fname,"spll-helper-kp-%f-ki-%f.dat", kp_gains[pp],ki_gains[ii]);
		FILE *f_out=fopen(fname,"wb");
		fprintf(f_out,"main kp=%f ki=%f\n", -kp_gains[pp],-ki_gains[ii]);
		spll_readout_ertm14( handle, f_out, 3 );
		fclose(f_out);
		fflush(stdout);
	}
	}

	return 0;
}


#if 0
	int timeout = 120;
	if( argc >= 2 )
		timeout = atoi(argv[1]);

	int good_samples = 0;

	for(;;)
	{
		ertm_wr_diags(handle, &handle->state->wr_status);

		uint32_t aux0_stat = handle->state->wr_status.WDIAG_AUX0_DETAIL_STAT;
		struct ertm_wr_status *st = &handle->state->wr_status;


		//printf("aux0: %08x\n", aux0_stat );

		if( aux0_stat & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_LOCKED )
		{
			uint32_t phase = aux0_stat & 0xffffff;
			if(good_samples == 3 )
			{
				printf("[%d,%llu,%llu,%d,%d,%d]\n", phase,
					((unsigned long long) st->WDIAG_MU_MSB << 32 ) | st->WDIAG_MU_LSB,
					((unsigned long long) st->WDIAG_DMS_MSB << 32 ) | st->WDIAG_DMS_LSB,
					st->WDIAG_ASYM,
					st->WDIAG_CKO,
					st->WDIAG_SETP );
				break;
			}

			good_samples++;
			timeout--;

			if(!timeout)
			{
				printf("Timeout!\n");
				fflush(stdout);
				ertm_exit(handle);
				return 0;
			}
		}

		fflush(stdout);

		sleep(1);
	}

	ertm_exit(handle);

	return 0;
}

#endif
