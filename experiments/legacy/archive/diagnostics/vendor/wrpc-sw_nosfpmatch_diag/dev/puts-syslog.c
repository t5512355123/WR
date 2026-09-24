#include <wrc.h>
#include <string.h>
#include <shell.h>
#include <lib/syslog.h>

int syslog_puts(const char *s)
{
	char new_s[CONFIG_PRINT_BUFSIZE + 4];
	int l, ret;

	l = strlen(s);
	ret = l;

	/* avoid shell-interation stuff */
	if (shell_is_interacting)
		return ret;
	if (l < 2 || s[0] == '\e')
		return ret;
	if (!strncmp(s, "wrc#", 4))
		return ret;

	/* if not terminating with newline, add a trailing "...\n" */
	strcpy(new_s, s);
	if (s[l-1] != '\n') {
		new_s[l++] = '.';
		new_s[l++] = '.';
		new_s[l++] = '.';
		new_s[l++] = '\n';
		new_s[l++] = '\0';
	}
	syslog_report(new_s);
	return ret;
}
