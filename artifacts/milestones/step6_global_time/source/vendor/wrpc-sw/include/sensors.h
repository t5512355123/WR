/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2016 GSI (www.gsi.de)
 * Author: Alessandro rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __SENSORS_H__
#define __SENSORS_H__

#include <stdint.h>

/* Flags.  */
#define WRC_SENSOR_TEMP_CELSIUS (1<<0)
#define WRC_SENSOR_CURRENT_MA (1<<1)
#define WRC_SENSOR_VOLTAGE_MV (1<<2)
#define WRC_SENSOR_VALID (1<<3)

#define WRC_SENSOR_INVALID_VALUE (0x80000000)

struct wrc_sensor
{
	const char* name;
	uint8_t flags;
	uint8_t id;
	int16_t value;
};

/* generic sensor functions */
void wrc_register_sensors( struct wrc_sensor* s);
struct wrc_sensor* wrc_sensor_find_by_name(char *name);
struct wrc_sensor* wrc_sensor_find_by_id(uint8_t id);
struct wrc_sensor* wrc_sensor_find_by_type(uint8_t type);

#endif /* __SENSORS_H__ */
