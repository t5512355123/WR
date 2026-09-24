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

/*
    char *ertm_perror(int error)
 */
static uint64_t get_tics(void)
{
	struct timezone tz = {0, 0};
	struct timeval tv;
	gettimeofday(&tv, &tz);

	return (uint64_t) tv.tv_sec * 1000000ULL + (uint64_t) tv.tv_usec;
}

int main(int argc, char *argv[])
{
	static char usb[] = "/dev/ttyUSB2";
	struct ertm_status *handle = ertm_init(NULL);
	int attempt;

	if (handle == NULL) {
		fprintf(stderr, "could not open %s\n", usb);
		exit(1);
	}

	printf("---------:  get_board_config -------------------------\n");
	ertm_get_board_config(handle, &handle->state->board_state);
	display_ertm_state(handle->state);
	printf("---------:  set_level_adjust LO 0.10 -------------------------\n");
	ertm_dds_set_level_adjust(handle, ERTM_LO, 0.10);
	ertm_get_board_config(handle, &handle->state->board_state);
	display_ertm_state(handle->state);
	printf("---------:  set_level_adjust LO 0.90 -------------------------\n");
	ertm_dds_set_level_adjust(handle, ERTM_LO, 0.90);
	ertm_get_board_config(handle, &handle->state->board_state);
	display_ertm_state(handle->state);
	printf("---------:  set_level_adjust REF 0.10 -------------------------\n");
	ertm_dds_set_level_adjust(handle, ERTM_REF, 0.10);
	ertm_get_board_config(handle, &handle->state->board_state);
	display_ertm_state(handle->state);
	printf("---------:  set_level_adjust REF 0.90 -------------------------\n");
	ertm_dds_set_level_adjust(handle, ERTM_REF, 0.90);
	ertm_get_board_config(handle, &handle->state->board_state);
	display_ertm_state(handle->state);
	printf("---------:  wr_diags -------------------------\n");
	ertm_wr_diags(handle, &handle->state->wr_status);
	display_wrc_diags_cooked(&handle->state->wr_status);
	printf("---------:  wr_enable 1 -------------------------\n");
	ertm_wr_enable(handle, 1);
	ertm_wr_diags(handle, &handle->state->wr_status);
	display_wrc_diags_cooked(&handle->state->wr_status);
	printf("---------:  wr_enable 0 -------------------------\n");
	ertm_wr_enable(handle, 0);
	ertm_wr_diags(handle, &handle->state->wr_status);
	display_wrc_diags_cooked(&handle->state->wr_status);
	printf("---------:  wr_enable 1 -------------------------\n");
	ertm_wr_enable(handle, 1);
	ertm_wr_diags(handle, &handle->state->wr_status);
	display_wrc_diags_cooked(&handle->state->wr_status);

	printf("---------:  check force power measurement -------------------------\n");

	for( attempt = 0; attempt < 5; attempt++ )
	{
		int ok = 0;
		ertm_force_measure_channels_power( handle );
		ertm_get_board_config(handle, &handle->state->board_state);

		if( handle->state->board_state.lo.amp_power & ERTM_FLAGS_DDS_POWER_VALID_MASK )
		{
			fprintf(stderr,"Warning, power valid flag didn't get invalidated after force measure channels power call\n");
		}

		uint64_t tmo = get_tics();

		while (tmo + 2000000ULL > get_tics() )
		{
			ertm_get_board_config(handle, &handle->state->board_state);

			if( handle->state->board_state.lo.amp_power & ERTM_FLAGS_DDS_POWER_VALID_MASK )
			{
				ok = 1;
				break;
			}
		}

		if( ok )
			printf("Power measurement received after %.0f ms\n", (double) (get_tics() - tmo) / 1000.0 );
		else
			printf("ERROR: Power measurement timeout expired.\n");

	}

	ertm_exit(handle);

	return 0;
}

