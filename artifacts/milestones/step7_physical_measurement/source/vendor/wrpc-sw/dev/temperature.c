/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2016 GSI (www.gsi.de)
 * Author: Alessandro rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <wrc.h>
#include <string.h>
#include <dev/temperature.h>
#include <shell.h>


struct wrc_temp_group temp_sensors[WRC_MAX_TEMPERATURES];

/*
 * Library functions
 */
uint32_t wrc_temp_get(char *name)
{
	struct wrc_temp_sensor *temp_sensor;
	struct wrc_temp_group *temp_group;
	int i;

	if (!name)
		return TEMP_INVALID;

	/* get search all temperature groups */
	for (i = 0; i < WRC_MAX_TEMPERATURES; i++) {
		temp_group = &temp_sensors[i];

		/* search all sensors within group */
		for (temp_sensor = temp_group->t; temp_sensor->name;
		     temp_sensor++) {
			if (!strcmp(name, temp_sensor->name)) {
				return temp_sensor->t;
			}
		}
	}

	return TEMP_INVALID;
}

struct wrc_temp_sensor *wrc_temp_getnext(struct wrc_temp_sensor *pt)
{
	struct wrc_temp_sensor *wt;
	struct wrc_temp_group *tmp;
	int i;

	if (!pt) { /* first one */
		for (i = 0; i < WRC_MAX_TEMPERATURES; i++) {
			return temp_sensors[i].t;
		}
	}
	if (pt[1].name)
		return pt + 1;
	/* get next array, if any */
	for (i = 0; i < WRC_MAX_TEMPERATURES; i++) {
		tmp = &temp_sensors[i];

		for (wt = tmp->t; wt->name; wt++) {
			if (wt == pt) {
				tmp++;
				if (!tmp->t->name)
					return NULL;
				return tmp->t;
			}
		}
	}
	return NULL;
}

extern int wrc_temp_format(char *buffer, int len)
{
	struct wrc_temp_sensor *p;
	int l = 0, i = 0;
	int32_t t;

	for (p = wrc_temp_getnext(NULL); p; p = wrc_temp_getnext(p), i++) {
		if (l + 16 > len) {
			l += sprintf(buffer + l, " ENOSPC");
			return l;
		}
		t = p->t;
		l += sprintf(buffer + l, "%s%s:", i ? " " : "", p->name);
		if (t == TEMP_INVALID) {
			l += sprintf(buffer + l, "INVALID");
			continue;
		}
		if (t < 0) {
			t = -(signed)t;
			l += sprintf(buffer + l, "-");
		}
		l += sprintf(buffer + l,"%d.%04d", (int) (t >> 16),
			     (int) ((t & 0xffff) * 10 * 1000 >> 16));
	}
	return l;
}

int wrc_temp_register(struct wrc_temp_group *new_temp_sensor)
{
	int i;

	for (i = 0; i < WRC_MAX_TEMPERATURES; i++) {
		struct wrc_temp_group *grp = &temp_sensors[i];
		if (grp->t) {
			/* slot used in the list */
			continue;
		}
		*grp = *new_temp_sensor;

		return 1;
	}

	return 0;
}

/*
 * The task
 */
int wrc_temp_refresh(void)
{
	int i;
	int ret = 0;

	for (i = 0; i < WRC_MAX_TEMPERATURES; i++) {
		struct wrc_temp_group *grp = &temp_sensors[i];
		struct wrc_temp_sensor *sensor;

		if (!grp->t)
			continue;
		for (sensor = grp->t; sensor->name; sensor++)
			ret += grp->read(sensor);
	}

	return (ret > 0);
}

/*
 * The shell command
 */

static int cmd_temp(const char *args[])
{
	char buffer[80];

	wrc_temp_format(buffer, sizeof(buffer));
	pp_printf("%s\n", buffer);
	return 0;
}


DEFINE_WRC_COMMAND(temp) = {
	.name = "temp",
	.exec = cmd_temp,
};
