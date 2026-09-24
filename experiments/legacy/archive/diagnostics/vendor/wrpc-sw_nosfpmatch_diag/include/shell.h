/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __SHELL_H
#define __SHELL_H

#include <stdint.h>

#define UI_SHELL_MODE 0
#define UI_GUI_MODE 1

#define SH_MAX_LINE_LEN 80
#define SH_MAX_ARGS 8

extern int wrc_ui_mode;
extern int wrc_stat_running;

/* refresh period for _gui_ and _stat_ commands */
extern int wrc_ui_refperiod;

/* internal "last", exported to shell command */
extern uint32_t wrc_stats_last;

void decode_mac(const char *str, unsigned char *mac);
char *format_mac(char *s, const unsigned char *mac);
void decode_ip(const char *str, unsigned char *ip);
char *format_ip(char *s, const unsigned char *ip);

struct wrc_shell_cmd {
	const char *name;
	int (*exec) (const char *args[]);
};

/* Put the structures in their own section */
#define DEFINE_WRC_COMMAND(_name) \
	const struct wrc_shell_cmd __wrc_cmd_ ## _name 

char *env_get(const char *var);
int env_set(const char *var, const char *value);
void env_init(void);

int shell_exec(const char *buf);
int shell_interactive(void);
extern unsigned char shell_is_interacting;

/* Command sub-menu: the command of CMD (of length LEN) is selected
   according to ARGS[0] and its index returned.
   If the command is not found, a small help is displayed and -1 is returned.
*/
int sub_cmd(const char * const *cmds, unsigned len, const char *args[]);

void shell_boot_script(void);
void shell_show_build_init(void);
void shell_register_command( const struct wrc_shell_cmd* cmd );
void shell_list_cmds(void);
void shell_register_commands(void);
void shell_activate_ui_command( int (*callback)(void) );

#endif
