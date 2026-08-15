/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <limits.h>

/* platform independent timespec-like data structure */
struct pp_cfg_time {
	long tv_sec;
	long tv_nsec;
};

/* Data structure used to pass just a single argument to configuration
 * functions. Any future new type for any new configuration function can be just
 * added inside here, without redefining cfg_handler prototype */
union pp_cfg_arg {
	int i;
	int i2[2];
	int64_t i64;
	double d;
	Boolean b;
	char *s;
	struct pp_cfg_time ts;
};

/*
 * Configuration: we are structure-based, and a typedef simplifies things
 */
struct pp_argline;

typedef int (*cfg_handler)(struct pp_argline *l, int lineno,
			   struct pp_globals *ppg, union pp_cfg_arg *arg);

struct pp_argname {
	char *name;
	int value;
};
enum pp_argtype {
	ARG_NONE,
	ARG_INT,
	ARG_INT2,
	ARG_STR,
	ARG_NAMES,
	ARG_TIME,
	ARG_DOUBLE,
	ARG_INT64
};

/* This enumeration gives the list of run-time options that should be marked when they are set in the configuration */
enum {
	OPT_RT_NO_UPDATE=0,
};


typedef struct {
	union min {
		int min_int;
		Integer64 min_int64;
		double min_double;
	}min;
	union max{
		int max_int;
		Integer64 max_int64;
		double max_double;
	}max;
}pp_argline_min_max_t;

struct pp_argline {
	cfg_handler f;
	char *keyword;	/* Each line starts with a keyword */
	enum pp_argtype t;
	struct pp_argname *args;
	size_t field_offset;
	int needs_port;
	pp_argline_min_max_t min_max;
};

/* Below are macros for setting up pp_argline arrays */
#define OFFS(s,f) offsetof(s, f)

#define OPTION_OPEN() {
#define OPTION_CLOSE() }
#define OPTION(s,func,k,typ,a,field,np)	\
		.f = func,						\
		.keyword = k,						\
		.t = typ,						\
		.args = a,						\
		.field_offset = OFFS(s,field),				\
		.needs_port = np,

#define LEGACY_OPTION(func,k,typ)					\
	{								\
		.f = func,						\
		.keyword = k,						\
		.t = typ,						\
	}

#define INST_OPTION(func,k,t,a,field)					\
    OPTION_OPEN() \
	OPTION(struct pp_instance,func,k,t,a,field,1) \
	OPTION_CLOSE()

#define INST_OPTION_FCT(func,k,t)					\
	    OPTION_OPEN() \
		OPTION(struct pp_instance,func,k,t,NULL,cfg,1) \
		OPTION_CLOSE()

#define INST_OPTION_STR(k,field)					\
	INST_OPTION(f_string,k,ARG_STR,NULL,field)

#define INST_OPTION_INT_RANGE(k,t,a,field,mn,mx)					\
	OPTION_OPEN() \
	OPTION(struct pp_instance,f_simple_int,k,t,a,field,1) \
	.min_max.min.min_int = mn,\
	.min_max.max.max_int = mx,\
	OPTION_CLOSE()

#define INST_OPTION_INT(k,t,a,field)					\
		INST_OPTION_INT_RANGE(k,t,a,field,INT_MIN,INT_MAX)


#define INST_OPTION_BOOL(k,field)					\
	INST_OPTION(f_simple_bool,k,ARG_NAMES,arg_bool,field)

#define INST_OPTION_INT64_RANGE(k,t,a,field,mn,mx)					\
	OPTION_OPEN() \
	OPTION(struct pp_instance,f_simple_int64,k,t,a,field,1) \
	.min_max.min.min_int64 = mn,\
	.min_max.max.max_int64 = mx,\
	OPTION_CLOSE()

#define INST_OPTION_INT64(k,t,a,field)					\
		INST_OPTION_INT64_RANGE(k,t,a,field,INT64_MIN,INT64_MAX)

#define INST_OPTION_DOUBLE_RANGE(k,t,a,field,mn,mx)					\
	OPTION_OPEN() \
	OPTION(struct pp_instance,f_simple_double,k,t,a,field,1) \
	.min_max.min.min_double = mn,\
	.min_max.max.max_double = mx,\
	OPTION_CLOSE()

#define INST_OPTION_DOUBLE(k,t,a,field)					\
		INST_OPTION_DOUBLE_RANGE(k,t,a,field,-DBL_MAX,DBL_MAX)

#define RT_OPTION(func,k,t,a,field)					\
	OPTION_OPEN() \
	OPTION(struct pp_runtime_opts,func,k,t,a,field,0)\
	OPTION_CLOSE()

#define RT_OPTION_INT_RANGE(k,t,a,field,mn,mx)					\
	OPTION_OPEN() \
	OPTION(struct pp_runtime_opts,f_simple_int,k,t,a,field,0) \
	.min_max.min.min_int = mn,\
	.min_max.max.max_int = mx,\
	OPTION_CLOSE()

#define RT_OPTION_INT(k,t,a,field)					\
	RT_OPTION_INT_RANGE(k,t,a,field,INT_MIN,INT_MAX)

#define RT_OPTION_BOOL(k,field)					\
	RT_OPTION(f_simple_bool,k,ARG_NAMES,arg_bool,field)

#define RT_OPTION_BOOL_TRUE(k,field)					\
	RT_OPTION(f_simple_bool,k,ARG_NAMES,arg_bool_true,field)

#define RT_OPTION_BOOL_FALSE(k,field)					\
	RT_OPTION(f_simple_bool,k,ARG_NAMES,arg_bool_false,field)


#define GLOB_OPTION(func,k,t,a,field)					\
	OPTION_OPEN() \
	OPTION(struct pp_globals,func,k,t,a,field,0) \
	OPTION_CLOSE()

#define GLOB_OPTION_INT_RANGE(k,t,a,field,mn,mx)					\
	OPTION_OPEN() \
	OPTION(struct pp_globals,f_simple_int,k,t,a,field,0) \
	.min_max.min.min_int = mn,\
	.min_max.max.max_int = mx,\
	OPTION_CLOSE()

#define GLOB_OPTION_INT(k,t,a,field)					\
	GLOB_OPTION_INT_RANGE(k,t,a,field,INT_MIN,INT_MAX)

/* Both the architecture and the extension can provide config arguments */
extern struct pp_argline pp_arch_arglines[];
extern struct pp_argline pp_ext_arglines[];

/* Note: config_string modifies the string it receives */
extern int pp_config_string(struct pp_globals *ppg, char *s);
extern int pp_config_file(struct pp_globals *ppg, int force, char *fname);
extern int f_simple_int(struct pp_argline *l, int lineno,
			struct pp_globals *ppg, union pp_cfg_arg *arg);
