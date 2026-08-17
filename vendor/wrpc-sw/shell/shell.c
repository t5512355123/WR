/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Copyright (C) 2012 GSI (www.gsi.de)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <wrc.h>
#include "sensors.h"
#include "dev/console.h"
#include "dev/dac_log.h"
#include "dev/syscon.h"
#include "dev/temp-fake.h"
#include "dev/temp-w1.h"
#include "dev/w1.h"
#include "dev/temperature.h"

#include "shell.h"
#include "storage.h"
#include "lib/syslog.h"

/* interactive shell state definitions */

#define SHELL_MAX_COMMANDS 40

#define SH_PROMPT 0
#define SH_INPUT 1
#define SH_EXEC 2
#define SH_EXEC_UI 3

#define ESCAPE_FLAG 0x100

#define KEY_LEFT (ESCAPE_FLAG | 68)
#define KEY_RIGHT (ESCAPE_FLAG | 67)
#define KEY_ENTER (13)
#define KEY_ENTER10 (10)
#define KEY_ESCAPE (27)
#define KEY_BACKSPACE (127)
#define KEY_DELETE (126)

#ifdef CONFIG_CMD_PPS
#define HAS_CMD_PPS 1
#else
#define HAS_CMD_PPS 0
#endif

#ifdef CONFIG_CMD_LEAPSEC
#define HAS_CMD_LEAPSEC 1
#else
#define HAS_CMD_LEAPSEC 0
#endif

#ifdef CONFIG_CMD_LL
#define HAS_CMD_LL 1
#else
#define HAS_CMD_LL 0
#endif

#ifdef CONFIG_CMD_NETCONSOLE
#define HAS_CMD_NETCONSOLE 1
#else
#define HAS_CMD_NETCONSOLE 0
#endif

#ifdef CONFIG_CMD_CONFIG
#define HAS_CMD_CONFIG 1
#else
#define HAS_CMD_CONFIG 0
#endif

#ifdef CONFIG_CMD_REFRESH
#define HAS_CMD_REFRESH 1
#else
#define HAS_CMD_REFRESH 0
#endif

#ifdef CONFIG_LATENCY_PROBE
#define HAS_LATENCY_PROBE 1
#else
#define HAS_LATENCY_PROBE 0
#endif

#ifdef CONFIG_GENERIC_SENSORS
#define HAS_GENERIC_SENSORS 1
#else
#define HAS_GENERIC_SENSORS 0
#endif

#ifdef CONFIG_FREQUENCY_MONITOR
#define HAS_FREQUENCY_MONITOR 1
#else
#define HAS_FREQUENCY_MONITOR 0
#endif


static char cmd_buf[SH_MAX_LINE_LEN + 1];
static int cmd_pos = 0, cmd_len = 0;
static unsigned char state = SH_PROMPT;
static uint16_t current_key = 0;

static const struct wrc_shell_cmd *cmds[ SHELL_MAX_COMMANDS ];
static int n_cmds = 0;

unsigned char shell_is_interacting;
int (*shell_ui_callback)(void);

static int insert(char c)
{
	if (cmd_len >= SH_MAX_LINE_LEN)
		return 0;

	if (cmd_pos != cmd_len)
		memmove(&cmd_buf[cmd_pos + 1], &cmd_buf[cmd_pos],
			cmd_len - cmd_pos);

	cmd_buf[cmd_pos] = c;
	cmd_pos++;
	cmd_len++;

	return 1;
}

static void delete(int where)
{
	memmove(&cmd_buf[where], &cmd_buf[where + 1], cmd_len - where);
	cmd_len--;
}

static void esc(char code)
{
	pp_printf("\033[1%c", code);
}

int sub_cmd(const char * const *cmds, unsigned len, const char *args[])
{
	unsigned i;

	if (args[0]) {
		for (i = 0; i < len; i++) {
			if (!strcmp (cmds[i], args[0]))
				return i;
		}
	}

	pp_printf ("usage:\n");
	for (i = 0; i < len; i++) {
		/* Hack: we know we are called from shell_exec, so
		   args[-1] is valid. */
		pp_printf(" %s %s\n", args[-1], cmds[i]);
	}
	return -1;
}

static int _shell_exec(void)
{
	const char *tokptr[SH_MAX_ARGS + 1];
	const struct wrc_shell_cmd *p;
	int n = 0, i = 0, rv;

	memset(tokptr, 0, sizeof(tokptr));

	while (1) {
		if (n >= SH_MAX_ARGS)
			break;

		/* Skip spaces at the start and before an argument.
		   Replace them with a null byte to mark end of string. */
		while (cmd_buf[i] == ' ')
			cmd_buf[i++] = 0;

		/* End of line. */
		if (!cmd_buf[i])
			break;

		/* New argument. */
		tokptr[n++] = &cmd_buf[i];

		/* Skip it. */
		while (cmd_buf[i] != ' ' && cmd_buf[i])
			i++;

		if (!cmd_buf[i])
			break;
	}

	if (!n)
		return 0;

	if (*tokptr[0] == '#')
		return 0;

	for (i = 0; i < n_cmds; i++)
	{
		p = cmds[i];
		if (!strcasecmp(p->name, tokptr[0])) {
			rv = p->exec(tokptr + 1);
			if (rv < 0)
				pp_printf("Command \"%s\": error %d\n",
					p->name, rv);
			return rv;
		}
	}

	pp_printf("Unrecognized command \"%s\".\n", tokptr[0]);
	return -EINVAL;
}

int shell_exec(const char *cmd)
{
	int i;

	if (cmd != cmd_buf)
		strncpy(cmd_buf, cmd, SH_MAX_LINE_LEN);
	cmd_len = strlen(cmd_buf);
	shell_is_interacting = 1;
	i = _shell_exec();
	shell_is_interacting = 0;
	/* clean cmd_buf */
	cmd_buf[0] = '\0';
	return i;
}

void shell_init()
{
	cmd_len = cmd_pos = 0;
	state = SH_PROMPT;
	shell_ui_callback = NULL;
}

int shell_interactive()
{
	int c;

	switch (state) {
	case SH_PROMPT:
		pp_printf("wrc# ");
		cmd_pos = 0;
		cmd_len = 0;
		state = SH_INPUT;
		return 1;

	case SH_INPUT:
		c = console_getc();

		if (c < 0)
			return 0;

		if (c == 27 || ((current_key & ESCAPE_FLAG) && c == '['))
			current_key = ESCAPE_FLAG;
		else
			current_key |= c;

		if (current_key & 0xff) {

			switch (current_key) {
			case KEY_LEFT:
				if (cmd_pos > 0) {
					cmd_pos--;
					esc('D');
				}
				break;
			case KEY_RIGHT:
				if (cmd_pos < cmd_len) {
					cmd_pos++;
					esc('C');
				}
				break;

			case KEY_ENTER:
			case KEY_ENTER10:
				pp_printf("\n");
				state = SH_EXEC;
				break;

			case KEY_DELETE:
				if (cmd_pos != cmd_len) {
					delete(cmd_pos);
					esc('P');
				}
				break;

			case KEY_BACKSPACE:
				if (cmd_pos > 0) {
					esc('D');
					esc('P');
					delete(cmd_pos - 1);
					cmd_pos--;
				}
				break;

			case '\t':
				break;

			default:
				if (!(current_key & ESCAPE_FLAG)
				    && insert(current_key)) {
					esc('@');
					pp_printf("%c", current_key);
				}
				break;

			}
			current_key = 0;
		}
		return 1;

	case SH_EXEC:
		cmd_buf[cmd_len] = 0;
		_shell_exec();

// fixme: ugly hack, we should manage the shell FSM state in a cleaner way.
		if( state == SH_EXEC_UI )
			return 1;

		state = SH_PROMPT;
		return 1;


	case SH_EXEC_UI:
		c = console_getc();
		if (c == 'r')
			redraw_gui();

		if (!shell_ui_callback || shell_ui_callback() < 0 || c == 27 || c == 'q')
		{
			cmd_buf[cmd_len] = 0;
			state = SH_PROMPT;
		}
		return 1;
	}
	return 0;
}

#ifdef CONFIG_INIT_COMMAND
static const char shell_init_cmd[] = CONFIG_INIT_COMMAND;

static int build_init_readcmd(uint8_t *cmd, int maxlen)
{
	static const char *p = shell_init_cmd;
	int i;

	/* use semicolon as separator */
	for (i = 0; i < maxlen && p[i] && p[i] != ';'; i++)
		cmd[i] = p[i];
	cmd[i] = '\0';
	p += i;
	if (*p == ';')
		p++;
	if (i == 0) {
		/* it's the last call, roll-back *p to be ready for the next
		 * call */
		p = shell_init_cmd;
	}
	return i;
}
#endif

void shell_boot_script(void)
{
	int next = 0;

#ifdef CONFIG_INIT_COMMAND
	while (1) {
		cmd_len = build_init_readcmd((uint8_t *)cmd_buf,
					SH_MAX_LINE_LEN);
		if (!cmd_len)
			break;
		pp_printf("executing: %s\n", cmd_buf);
		shell_exec(cmd_buf);
	}
#endif

	while (CONFIG_HAS_FLASH_INIT) {
		cmd_len = storage_init_readcmd((uint8_t *)cmd_buf,
					      SH_MAX_LINE_LEN, next);
		if (cmd_len <= 0) {
			if (next == 0)
				pp_printf("Empty init script...\n");
			break;
		}
		cmd_buf[cmd_len - 1] = 0;

		pp_printf("executing: %s\n", cmd_buf);
		shell_exec(cmd_buf);
		next = 1;
	}

	return;
}

void shell_show_build_init(void)
{
	int i = 0;

	pp_printf("-- built-in script --\n");
#ifdef CONFIG_INIT_COMMAND
	while (1) {
		cmd_len = build_init_readcmd((uint8_t *)cmd_buf,
					SH_MAX_LINE_LEN);
		if (!cmd_len)
			break;
		pp_printf("%s\n", cmd_buf);
		++i;
	}
#endif
	if (!i)
		pp_printf("(empty)\n");
}


void shell_register_command(const struct wrc_shell_cmd* cmd)
{
	if( n_cmds >= SHELL_MAX_COMMANDS )
	{
		pp_printf("can't register shell command '%s', increase SHELL_MAX_COMMANDS\n", cmd->name );
		return;
	}
	cmds[ n_cmds ] = cmd;
	n_cmds++;
}

void shell_activate_ui_command( int (*callback)(void) )
{
	shell_ui_callback = callback;
	state = SH_EXEC_UI;
	term_clear();
	cmd_len = 0;
}

static int cmd_help(const char *args[])
{
	int i;
	pp_printf("Available commands:\n");

	for(i = 0; i < n_cmds; i++) {
		pp_printf(" %s\n", cmds[i]->name);
	}

	return 0;
}

static DEFINE_WRC_COMMAND(help) = {
	.name = "help",
	.exec = cmd_help,
};

#define REGISTER_WRC_COMMAND(_name) \
	{ extern const struct wrc_shell_cmd __wrc_cmd_ ## _name; shell_register_command( &__wrc_cmd_ ## _name ); }

void shell_register_commands(void)
{
	REGISTER_WRC_COMMAND(calibration);
	if (HAS_CMD_CONFIG)
		REGISTER_WRC_COMMAND(config);
	if (HAS_DAC_LOG)
		REGISTER_WRC_COMMAND(daclog);
	if (HAS_CMD_LL)
		REGISTER_WRC_COMMAND(delays);
	if (HAS_CMD_LL)
		REGISTER_WRC_COMMAND(devmem);
	REGISTER_WRC_COMMAND(diag);
	if (HAS_TEMP_FAKE)
		REGISTER_WRC_COMMAND(faketemp);
	REGISTER_WRC_COMMAND(gui);
	REGISTER_WRC_COMMAND(help);
	REGISTER_WRC_COMMAND(init);
	if (HAS_IP)
		REGISTER_WRC_COMMAND(ip);
	if (HAS_CMD_LEAPSEC)
		REGISTER_WRC_COMMAND(leapsec);
	if (HAS_LATENCY_PROBE)
		REGISTER_WRC_COMMAND(ltest);
	REGISTER_WRC_COMMAND(mac);
	REGISTER_WRC_COMMAND(mode);
	if (HAS_CMD_NETCONSOLE)
		REGISTER_WRC_COMMAND(netconsole);
	REGISTER_WRC_COMMAND(pll);
	if (HAS_CMD_PPS)
		REGISTER_WRC_COMMAND(pps);
	REGISTER_WRC_COMMAND(ps);
	REGISTER_WRC_COMMAND(ptp);
	REGISTER_WRC_COMMAND(ptrack);
	if (HAS_CMD_REFRESH)
		REGISTER_WRC_COMMAND(refresh);
	REGISTER_WRC_COMMAND(sdb);
	REGISTER_WRC_COMMAND(sfp);
	REGISTER_WRC_COMMAND(sleep);
	REGISTER_WRC_COMMAND(stat);
	if (HAS_SYSLOG)
		REGISTER_WRC_COMMAND(syslog);
	if (HAS_TEMP_SENSORS)
		REGISTER_WRC_COMMAND(temp);
	if (HAS_GENERIC_SENSORS)
		REGISTER_WRC_COMMAND(sensors);
	REGISTER_WRC_COMMAND(time);
	REGISTER_WRC_COMMAND(uptime);
	REGISTER_WRC_COMMAND(ver);
	REGISTER_WRC_COMMAND(verbose);
	if (HAS_VLANS)
		REGISTER_WRC_COMMAND(vlan);
	if (HAS_W1_TEMP)
		REGISTER_WRC_COMMAND(w1);
	if (HAS_W1_EEPROM) {
		REGISTER_WRC_COMMAND(w1r);
		REGISTER_WRC_COMMAND(w1w);
	}
	if( HAS_FREQUENCY_MONITOR )
		REGISTER_WRC_COMMAND(freqmon);
}
