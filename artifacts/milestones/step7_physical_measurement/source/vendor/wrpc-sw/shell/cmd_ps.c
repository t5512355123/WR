/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2016 GSI (www.gsi.de)
 * Author: Alessandro Rubini <a.rubini@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <wrc.h>
#include <string.h>
#include <shell.h>

#include "wrc-task.h"

extern uint32_t print_task_time_threshold;

static int cmd_ps(const char *args[])
{
	struct wrc_task *t;
	int i;

	if (args[0]) {
		if(!strcasecmp(args[0], "reset")) {
			for(i = 0; i < WRC_MAX_TASKS; i++)
			{
				t = wrc_task_get(i);
				if(!t)
					return 0;
				if(!t->used)
					continue;
				t->nrun = t->seconds = t->nanos = t->max_run_ticks = 0;
			}
			return 0;
		} else if (!strcasecmp(args[0], "max")) {
			if (args[1])
				print_task_time_threshold = atoi(args[1]);
			pp_printf("print_task_time_threshold %d\n",
				  (unsigned int) print_task_time_threshold);
			return 0;
		}
	}
	pp_printf(" iterations     seconds.micros    max_ms name\n");
	for(i = 0; i < WRC_MAX_TASKS; i++)
	{
		t = wrc_task_get(i);
		if(!t)
			return 0;
		if(!t->used)
			continue;
		pp_printf("  %9li   %9li.%06li %9ld %s\n", t->nrun,
					t->seconds, t->nanos/1000, t->max_run_ticks, t->name);
	}
	return 0;
}

DEFINE_WRC_COMMAND(ps) = {
	.name = "ps",
	.exec = cmd_ps,
};
