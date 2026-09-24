/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

#define CMD_LINE_SEPARATOR {"", ""}

struct cmd_line_opt {
	char *flag;
	char *help;
};
static struct cmd_line_opt cmd_line_list[] = {
	{"-?", "show this page"},
	/* FIXME cmdline check if useful */
	//{"-c", "run in command line (non-daemon) mode"},
	//{"-S", "send output to syslog"},
	//{"-T", "set multicast time to live"},
	//{"-d", "display stats"},
	//{"-D", "display stats in .csv format"},
	//{"-R", "record data about sync packets in a file"},
	{"-C CONFIG_ITEM", "set configuration options as stated in CONFIG_ITEM\n\t"
		"CONFIG_ITEM must be a valid config string, enclosed by \" \""},
	{"-f FILE", "read configuration file"},
	{"-d STRING", "diagnostic level (see diag-macros.h)\n\t"
		"FSM, Time, Frames, Servo, BMC, Extension, Configuration"},
	CMD_LINE_SEPARATOR,
	{"-t", "do not adjust the system clock"},
	{"-w NUMBER", "specify meanDelay filter stiffness"},
	CMD_LINE_SEPARATOR,
	//{"-u ADDRESS", "also send uni-cast to ADDRESS\n"}, -- FIXME: useful?
	{"-g", "run as slave only"},
	CMD_LINE_SEPARATOR,
	{NULL, NULL}
};

static void cmd_line_print_help(void)
{
	int i = 0;
	pp_printf("\nUsage: ppsi [OPTION]\n\n");

	while (1) {
		struct cmd_line_opt *o = &cmd_line_list[i];
		if (o->flag == NULL)
			break;
		pp_printf("%s\n\t%s\n", o->flag, o->help);
		i++;
	}
}

int pp_parse_cmdline(struct pp_globals *ppg, int argc, char **argv)
{
	int i, err = 0;
	char *a; /* cmd line argument */

	for (i = 1; i < argc; i++) {
		a = argv[i];
		if (a[0] != '-')
			err = 1;
		else if (a[1] == '?')
			err = 1;
		else if (a[1] && a[2])
			err = 1;
		if (err) {
			cmd_line_print_help();
			return -1;
		}

		switch (a[1]) {
		case 'd':
			/* Use the general flags, per-instance TBD */
			a = argv[++i];
			pp_global_d_flags = pp_diag_parse(a);
			break;
		case 'C':
			if (pp_config_string(ppg, argv[++i]) != 0)
				return -1;
			break;
		case 'f':
			if (pp_config_file(ppg, 1, argv[++i]) != 0)
				return -1;
			break;
		case 't':
			GOPTS(ppg)->flags |= PP_FLAG_NO_ADJUST;
			break;
		case 'w':
			a = argv[++i];
			GOPTS(ppg)->s = atoi(a);
			break;
		case 'h':
			/* ignored: was "GOPTS(ppg)->e2e_mode = 1;" */
			break;
		case 'G':
			/* gptp_mode not supported: fall through */
		default:
			cmd_line_print_help();
			return -1;
		}
	 }
	return 0;
}
