/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2016 GSI (www.gsi.de)
 * Author: Alessandro rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __TEMPERATURE_H__
#define __TEMPERATURE_H__

#include <stdint.h>

#ifdef CONFIG_TEMP_SENSORS
#define HAS_TEMP_SENSORS 1
#define WRC_MAX_TEMPERATURES 4
#else
#define HAS_TEMP_SENSORS 0
#define WRC_MAX_TEMPERATURES 0
#endif

#define TEMP_INVALID (0x8000 << 16)

/* A single temperature sensor */
struct wrc_temp_sensor {
	char *name;
	int32_t t;  /* fixed point, 16.16 (signed!) */
};

/* A list of temperature sensors */
struct wrc_temp_group {
	int (*read)(struct wrc_temp_sensor *);
	struct wrc_temp_sensor *t; /* zero-terminated */
};

/* lib functions  */
extern uint32_t wrc_temp_get(char *name);
struct wrc_temp_sensor *wrc_temp_getnext(struct wrc_temp_sensor *);
extern int wrc_temp_format(char *buffer, int len);
void wrc_temp_init(void);
int wrc_temp_refresh(void);
int wrc_temp_register(struct wrc_temp_group *new_temp_sensor);


#ifdef CONFIG_TEMP_SENSORS
extern struct wrc_temp_group temp_sensors[WRC_MAX_TEMPERATURES];
#endif

#endif /* __TEMPERATURE_H__ */
