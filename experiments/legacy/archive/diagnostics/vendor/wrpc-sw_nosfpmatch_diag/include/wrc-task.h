/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __WRC_TASK_H__
#define __WRC_TASK_H__

#include <board.h>

#ifndef WRC_MAX_TASKS
# define WRC_MAX_TASKS 20
#endif

/*
 * A task is a data structure, but currently suboptimal.
 * FIXME: init must return int, and both should get a pointer to data
 * (but doing this is heavy, and forces to change the submodule too).
 */

struct wrc_task {
	int used;
	char name[16];
	int (*enabled)(void);
	void (*init)(void);
	int (*job)(void);
	/* And we keep statistics about cpu usage */
	unsigned long nrun;
	unsigned long seconds;
	unsigned long nanos;
	unsigned long max_run_ticks; /* in ticks */
};

extern struct wrc_task tasks[WRC_MAX_TASKS];

void wrc_tasks_preinit(void);
struct wrc_task* wrc_task_create( const char *name, void (*init)(void), int (*job)(void) );
void wrc_task_set_enable( struct wrc_task* task, int (*enabled)(void) );
struct wrc_task *wrc_task_get(int tid);
void wrc_tasks_run_inits(void);
void wrc_poll_all_tasks(void);
void wrc_tasks_accounting_init(void);
int wrc_task_not_yet(uint32_t *lastt, unsigned period);

#endif /* __WRC_TASK_H__ */
