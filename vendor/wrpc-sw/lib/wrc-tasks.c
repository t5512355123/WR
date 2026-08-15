#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "wrc.h"
#include "wrc-task.h"
#include "dev/pps_gen.h"

#ifndef CONFIG_DEFAULT_PRINT_TASK_TIME_THRESHOLD
	#define CONFIG_DEFAULT_PRINT_TASK_TIME_THRESHOLD 0
#endif

static uint32_t prev_nanos_for_profile;
static uint32_t prev_ticks_for_profile;
uint32_t print_task_time_threshold = CONFIG_DEFAULT_PRINT_TASK_TIME_THRESHOLD;

struct wrc_task tasks[WRC_MAX_TASKS];

static void task_time_normalize(struct wrc_task *t)
{
	if (t->nanos > 1000 * 1000 * 1000) {
		t->nanos -= 1000 * 1000 * 1000;
		t->seconds++;
	}
}

/* Account the time to either this task or task 0 */
static void account_task(struct wrc_task *t, int done_sth)
{
	uint32_t nanos;
	signed int delta;
	uint32_t ticks;
	signed int delta_ticks;

	if (!done_sth)
		t = &tasks[0]; /* task 0 is special */
	shw_pps_gen_get_time(NULL, &nanos);
	/* get monotonic number of ticks */
	ticks = timer_get_tics();

	delta = nanos - prev_nanos_for_profile;
	if (delta < 0)
		delta += 1000 * 1000 * 1000;

	t->nanos += delta;
	task_time_normalize(t);
	prev_nanos_for_profile = nanos;

	delta_ticks = ticks - prev_ticks_for_profile;
	if (delta_ticks < 0)
		delta_ticks += TICS_PER_SECOND;

	if (t->max_run_ticks < delta_ticks) {/* update max_run_ticks */
		if (print_task_time_threshold) {
			/* Print only if threshold is set */
			pp_printf("New max run time for a task %s, old %ld, "
				  "new %d\n",
				  t->name, t->max_run_ticks, delta_ticks);
		}
		t->max_run_ticks = delta_ticks;
	}
	if (print_task_time_threshold
            && delta_ticks > print_task_time_threshold)
		pp_printf("task %s, run for %d ms\n", t->name, delta_ticks);

	prev_ticks_for_profile = ticks;
}

/* Run a task with profiling */
static void wrc_run_task(struct wrc_task *t)
{
	int done_sth = 0;

	if (!t->job) /* idle task, just count iterations */
		t->nrun++;
	else if (!t->enabled || t->enabled() ) {
		/* either enabled or without a check variable */
		done_sth = t->job();
		t->nrun += done_sth;
	}
	account_task(t, done_sth);
}

struct wrc_task* wrc_task_create( const char *name, void (*init)(void), int (*job)(void) )
{
	struct wrc_task *t = NULL;
	int i;

	for(i = 0; i < WRC_MAX_TASKS; i++)
		if(!tasks[i].used)
		{
			t = &tasks[i];
			break;
		}
	if(!t)
	{
		main_dbg("wrc_task_create() failed due to too many tasks (%d)\n", WRC_MAX_TASKS);
		return NULL;
	}

	t->used = 1;
	t->init = init;
	t->job = job;
	t->enabled = NULL;

	strncpy(t->name, name, 16);

	return t;
}

struct wrc_task *wrc_task_get(int tid)
{
    return &tasks[tid];
}

void wrc_task_set_enable( struct wrc_task* task, int (*enabled)(void) )
{
    task->enabled = enabled;
}

void wrc_tasks_preinit(void)
{
   	memset(&tasks, 0, sizeof(struct wrc_task) * WRC_MAX_TASKS);
}

void wrc_poll_all_tasks(void)
{
	int i;

	for( i = 0; i < WRC_MAX_TASKS; i++ )
		if( tasks[i].used )
		{
			wrc_run_task( &tasks[i] );
		}
}

void wrc_tasks_run_inits(void)
{
	int i;

	for( i = 0; i < WRC_MAX_TASKS; i++ )
		if( tasks[i].used && tasks[i].init )
		{
			tasks[i].init();
		}
}

void wrc_tasks_accounting_init(void)
{
	shw_pps_gen_get_time(NULL, &prev_nanos_for_profile);
	/* get tics */
	prev_ticks_for_profile = timer_get_tics();
}

int wrc_task_not_yet(uint32_t *lastt, unsigned period)
{
	uint32_t now = timer_get_tics();

	if (!*lastt) {
		*lastt = now;
		return 0;
	}
	if (time_before(now, *lastt + period))
		return 1; /* not yet */

	*lastt += period;
	return 0;
}
