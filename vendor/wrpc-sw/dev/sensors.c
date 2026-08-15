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
#include <sensors.h>
#include <shell.h>


#ifdef CONFIG_GENERIC_SENSORS

static struct wrc_sensor *sensors = NULL;

const char* sensor_type_string( uint8_t flags )
{
	if ( flags & WRC_SENSOR_TEMP_CELSIUS )
		return "Temperature";
	else if ( flags & WRC_SENSOR_VOLTAGE_MV )
		return "Voltage";
	else if ( flags & WRC_SENSOR_CURRENT_MA )
		return "Current";
	else
		return "?";
}

const char* sensor_unit_string( uint8_t flags )
{
	if ( flags & WRC_SENSOR_TEMP_CELSIUS )
		return "degC";
	else if ( flags & WRC_SENSOR_VOLTAGE_MV )
		return "mV";
	else if ( flags & WRC_SENSOR_CURRENT_MA )
		return "mA";
	else
		return "";
}

void wrc_register_sensors( struct wrc_sensor* s)
{
	sensors = s;
}

/*
 * Library functions
 */
struct wrc_sensor* wrc_sensor_find_by_name(char *name)
{
	struct wrc_sensor *s = sensors;
	while( s->flags )
	{
		if( !strcmp( name, s->name ) )
			return s;
		s++;
	}

	return NULL;
}

struct wrc_sensor* wrc_sensor_find_by_id(uint8_t id)
{
	struct wrc_sensor *s = sensors;
	while( s->flags )
	{
		if( s->id == id )
			return s;
		s++;
	}

	return NULL;
}

struct wrc_sensor* wrc_sensor_find_by_type(uint8_t type)
{
	struct wrc_sensor *s = sensors;
	while( s->flags )
	{
		if( s->flags & type )
			return s;
		s++;
	}

	return NULL;
}


/*
 * The shell command
 */

static int cmd_sensors(const char *args[])
{
	pp_printf("Sensors readout: \n");

	struct wrc_sensor *s;
	for (s = sensors; s->flags; s++) {
		if (!(s->flags & WRC_SENSOR_VALID))
			continue;
		pp_printf(" - %-20s %-20s : %05d %s\n",
			  sensor_type_string( s->flags ),
			  s->name,
			  s->value,
			  sensor_unit_string( s->flags )
			);
	}

	return 0;
}


DEFINE_WRC_COMMAND(sensors) = {
	.name = "sensors",
	.exec = cmd_sensors,
};

#endif /* CONFIG_GENERIC_SENSORS */
