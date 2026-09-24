/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Authors: Aurelio Colosimo, Alessandro Rubini
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
/* This file is built in hosted environments, so following headers are Ok */
#include <stdio.h>
#include <unistd.h>
#include <inttypes.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>


static inline struct pp_instance *CUR_PPI(struct pp_globals *ppg)
{
	if (ppg->cfg.cur_ppi_n < 0)
		return NULL;
	return INST(ppg, ppg->cfg.cur_ppi_n);
}

/* A "port" (or "link", for compatibility) line creates or uses a pp instance */
static int f_port(struct pp_argline *l, int lineno, struct pp_globals *ppg,
		  union pp_cfg_arg *arg)
{
	int i;

	/* First look for an existing port with the same name */
	for ( i = 0; i < ppg->nlinks; i++) {
		ppg->cfg.cur_ppi_n = i;
		if (!strcmp(arg->s, CUR_PPI(ppg)->cfg.port_name))
			return 0;
	}
	/* check if there are still some free pp_instances to be used */
	if (ppg->nlinks >= ppg->max_links) {
		pp_printf("config line %i: out of available ports\n",
			  lineno);
		/* we are out of available ports. set cur_ppi_n to -1 so if
		 * someone tries to set some parameter to this pp_instance it
		 * will cause an error, instead of overwrite the parameters of
		 * antother pp_instance */
		ppg->cfg.cur_ppi_n = -1;
		return -1;
	}
	ppg->cfg.cur_ppi_n = ppg->nlinks;

	 /* FIXME: strncpy (it is missing in bare archs by now) */
	strcpy(CUR_PPI(ppg)->cfg.port_name, arg->s);
	strcpy(CUR_PPI(ppg)->cfg.iface_name, arg->s); /* default iface name */
	ppg->nlinks++;
	return 0;
}

#define CHECK_PPI(need) /* Quick hack to factorize errors later */ 	\
	({if (need && !CUR_PPI(ppg)) {		\
		pp_printf("config line %i: no port for this config\n", lineno);\
		return -1; \
	} \
	if (!need && CUR_PPI(ppg)) { \
		pp_printf("config line %i: global config under \"port\"\n", \
			  lineno); \
		return -1; \
	}})

static inline void ASSIGN_INT_FIELD(struct pp_argline *l,
				    struct pp_globals *ppg,
					int v)
{
	void *dest=(l->needs_port) ? (void *)CUR_PPI(ppg) : (void *) GOPTS(ppg);

	/* Check min/max */
	if ( v<l->min_max.min.min_int || v>l->min_max.max.max_int) {
		pp_printf("Parameter %s(%ld) out of range\n", l->keyword, (long)v);\
		return;
	}
	*(int *)( dest + l->field_offset) = v;
}

int f_simple_int(struct pp_argline *l, int lineno,
		 struct pp_globals *ppg, union pp_cfg_arg *arg)
{
	CHECK_PPI(l->needs_port);
	ASSIGN_INT_FIELD(l, ppg, arg->i);
	return 0;
}

static inline void ASSIGN_INT64_FIELD(struct pp_argline *l,
				    struct pp_globals *ppg,
				    int64_t v)
{
	void *dest=(l->needs_port) ? (void *)CUR_PPI(ppg) : (void *) GOPTS(ppg);

	/* Check min/max */
	if ( v<l->min_max.min.min_int64 || v>l->min_max.max.max_int64 ) {
		pp_printf("Parameter %s(%" PRId64 ") out of range\n", l->keyword, v);\
		return;
	}
	*(int64_t *)( dest + l->field_offset) = v;
}

static int f_simple_int64(struct pp_argline *l, int lineno,
		 struct pp_globals *ppg, union pp_cfg_arg *arg)
{
	CHECK_PPI(l->needs_port);
	ASSIGN_INT64_FIELD(l, ppg, arg->i64);
	return 0;
}

static inline void ASSIGN_DOUBLE_FIELD(struct pp_argline *l,
				    struct pp_globals *ppg,
				    double v)
{
	void *dest=(l->needs_port) ? (void *)CUR_PPI(ppg) : (void *) GOPTS(ppg);

	/* Check min/max */
	if ( v<l->min_max.min.min_double || v>l->min_max.max.max_double ) {
		pp_printf("Parameter %s out of range\n", l->keyword);\
		return;
	}
	*(double *)( dest + l->field_offset) = v;
}

static int f_simple_double( struct pp_argline *l, int lineno,
		 struct pp_globals *ppg, union pp_cfg_arg *arg)
{
	CHECK_PPI(l->needs_port);
	ASSIGN_DOUBLE_FIELD(l, ppg, arg->d);
	return 0;
}

static inline void ASSIGN_BOOL_FIELD(struct pp_argline *l,
				    struct pp_globals *ppg,
				    Boolean v)
{
	void *dest=(l->needs_port) ? (void *)CUR_PPI(ppg) : (void *) GOPTS(ppg);

	*(Boolean *)( dest + l->field_offset) = v;
}

static int f_simple_bool( struct pp_argline *l, int lineno,
		 struct pp_globals *ppg, union pp_cfg_arg *arg)
{
	CHECK_PPI(l->needs_port);
	ASSIGN_BOOL_FIELD(l, ppg, arg->b);
	return 0;
}


static inline void ASSIGN_STRING_FIELD(struct pp_argline *l,
				    struct pp_globals *ppg,
				    char *src)
{
	void *dest=(l->needs_port) ? (void *)CUR_PPI(ppg) : (void *) GOPTS(ppg);

	strcpy((char *)dest+l->field_offset, src);
}

static int f_string(struct pp_argline *l, int lineno, struct pp_globals *ppg,
		union pp_cfg_arg *arg)
{
	CHECK_PPI(l->needs_port);
	ASSIGN_STRING_FIELD(l, ppg, arg->s);
	return 0;
}

/* Diagnostics can be per-port or global */
static int f_diag(struct pp_argline *l, int lineno, struct pp_globals *ppg,
		  union pp_cfg_arg *arg)
{
	unsigned long level = pp_diag_parse(arg->s);

	if (ppg->cfg.cur_ppi_n >= 0)
		CUR_PPI(ppg)->d_flags = level;
	else
		pp_global_d_flags = level;
	return 0;
}

/* VLAN support is per-port, and it depends on configuration items */
static int f_vlan(struct pp_argline *l, int lineno, struct pp_globals *ppg,
		  union pp_cfg_arg *arg)
{
	struct pp_instance *ppi = CUR_PPI(ppg);
	int i, n, *v;
	char ch, *s;

	CHECK_PPI(1);

	/* Refuse to add vlan support in non-raw mode */
	if (ppi->proto == PPSI_PROTO_UDP) {
		pp_printf("config line %i: VLANs with UDP: not supported\n",
			  lineno);
		return -1;
	}
	/* If there is no support, just warn */
	if (CONFIG_VLAN_ARRAY_SIZE == 0) {
		pp_printf("Warning: config line %i ignored:"
			  " this PPSI binary has no VLAN support\n",
			  lineno);
		return 0;
	}
	if (ppi->nvlans)
		pp_printf("Warning: config line %i overrides "
			  "previous vlan settings\n", lineno);

	s = arg->s;
	for (v = ppi->vlans, n = 0; n < CONFIG_VLAN_ARRAY_SIZE; n++, v++) {
		i = sscanf(s, "%i %c", v, &ch);
		if (!i)
			break;
		if (*v > 4095 || *v < 0) {
			pp_printf("config line %i: vlan out of range: %i "
				  "(valid is 0..4095)\n", lineno, *v);
			return -1;
		}
		if (i == 2 && ch != ',') {
			pp_printf("config line %i: unexpected char '%c' "
				  "after %i\n", lineno, ch, *v);
			return -1;
		}
		if (i == 2)
			s = strchr(s, ',') + 1;
		else break;
	}
	if (n == CONFIG_VLAN_ARRAY_SIZE) {
		pp_printf("config line %i: too many vlans (%i): max is %i\n",
			  lineno, n + 1, CONFIG_VLAN_ARRAY_SIZE);
		return -1;
	}
	ppi->nvlans = n + 1; /* item "n" has been assigend too, 0-based */

	for (i = 0; i < ppi->nvlans; i++)
		pp_diag(NULL, config, 2, "  parsed vlan %4i for %s (%s)\n",
			ppi->vlans[i], ppi->cfg.port_name, ppi->cfg.iface_name);

	ppi->proto = PPSI_PROTO_VLAN;
	return 0;
}

static int f_servo_pi(struct pp_argline *l, int lineno,
		      struct pp_globals *ppg, union pp_cfg_arg *arg)
{
	int n1, n2;

	CHECK_PPI(0);
	n1 = arg->i2[0]; n2 = arg->i2[1];
	/* no negative or zero attenuation */
	if (n1 < 1 || n2 < 1)
		return -1;
	GOPTS(ppg)->ap = n1;
	GOPTS(ppg)->ai = n2;
	return 0;
}

/* These are the tables for the parser */
static struct pp_argname arg_proto[] = {
	{"raw", PPSI_PROTO_RAW},
	{"udp", PPSI_PROTO_UDP},
	/* PROTO_VLAN is an internal modification of PROTO_RAW */
	{},
};

#define STR_BOOL_TRUE  "t true 1 on y yes"
#define STR_BOOL_FALSE "f false 0 off n no"

static struct pp_argname arg_bool[] = {
	{STR_BOOL_TRUE, 1},
	{STR_BOOL_FALSE, 0},
	{},
};

static struct pp_argname CAN_BE_UNUSED arg_bool_true[] = {
	{STR_BOOL_TRUE, 1},
	{},
};

static struct pp_argname CAN_BE_UNUSED arg_bool_false[] = {
	{STR_BOOL_FALSE, 0},
	{},
};

static struct pp_argname arg_states[] = {
	{ "initializing", PPS_INITIALIZING},
	{ "faulty", PPS_FAULTY},
	{ "disabled", PPS_DISABLED},
	{ "listening", PPS_LISTENING},
	{ "pre_master", PPS_PRE_MASTER},
	{ "master", PPS_MASTER},
	{ "passive", PPS_PASSIVE},
	{ "uncalibrated", PPS_UNCALIBRATED},
	{ "slave", PPS_SLAVE},
	{},
};

static struct pp_argname arg_profile[] = {
	{"none ptp", PPSI_PROFILE_PTP}, /* none is equal to ptp for backward compatibility */
#if CONFIG_HAS_PROFILE_WR
	{"whiterabbit wr", PPSI_PROFILE_WR},
#endif
#if CONFIG_HAS_PROFILE_HA
	{"highaccuracy ha", PPSI_PROFILE_HA},
#endif
#if CONFIG_HAS_PROFILE_CUSTOM
	{"custom", PPSI_PROFILE_CUSTOM},
#endif
	{},
};
static struct pp_argname arg_delayMechanism[] = {
	{"request-response delay e2e", MECH_E2E},
#if CONFIG_HAS_P2P
	{"peer-delay pdelay p2p", MECH_P2P},
#endif
	{},
};

static struct pp_argline pp_global_arglines[] = {
	INST_OPTION_FCT(f_port, "link port", ARG_STR),
	INST_OPTION_FCT(f_servo_pi, "servo-pi", ARG_INT2),
	INST_OPTION_FCT(f_vlan, "vlan", ARG_STR),
	INST_OPTION_FCT(f_diag, "diagnostic", ARG_STR),
	INST_OPTION_STR("iface",cfg.iface_name),
	INST_OPTION_BOOL("masterOnly", cfg.masterOnly),
	INST_OPTION_INT("proto", ARG_NAMES, arg_proto, proto),
	INST_OPTION_INT("extension profile", ARG_NAMES, arg_profile, cfg.profile),
	INST_OPTION_INT("mechanism dm", ARG_NAMES, arg_delayMechanism, cfg.delayMechanism),
	INST_OPTION_INT_RANGE("sync-interval logSyncInterval", ARG_INT, NULL, cfg.sync_interval,
			PP_MIN_SYNC_INTERVAL,PP_MAX_SYNC_INTERVAL),
	INST_OPTION_INT_RANGE("announce-interval logAnnounceInterval", ARG_INT, NULL, cfg.announce_interval,
			PP_MIN_ANNOUNCE_INTERVAL,PP_MAX_ANNOUNCE_INTERVAL),
	INST_OPTION_INT_RANGE("announce-receipt-timeout announceReceiptTimeout", ARG_INT, NULL, cfg.announce_receipt_timeout,
			PP_MIN_ANNOUNCE_RECEIPT_TIMEOUT,PP_MAX_ANNOUNCE_RECEIPT_TIMEOUT),
	INST_OPTION_INT_RANGE("min-delay-req-interval logMinDelayReqInterval", ARG_INT, NULL, cfg.min_delay_req_interval,
			PP_MIN_MIN_DELAY_REQ_INTERVAL,PP_MAX_MIN_DELAY_REQ_INTERVAL),
	INST_OPTION_INT_RANGE("min-pdelay-req-interval logMinPDelayReqInterval", ARG_INT, NULL, cfg.min_pdelay_req_interval,
			PP_MIN_MIN_PDELAY_REQ_INTERVAL,PP_MAX_MIN_PDELAY_REQ_INTERVAL),

#if CONFIG_HAS_EXT_L1SYNC
	INST_OPTION_INT_RANGE("l1sync-interval logL1SyncInterval", ARG_INT, NULL, cfg.l1syncInterval,
			L1E_MIN_L1SYNC_INTERVAL,L1E_MAX_L1SYNC_INTERVAL),
	INST_OPTION_INT_RANGE("l1sync-receipt-timeout l1SyncReceiptTimeout", ARG_INT, NULL, cfg.l1syncReceiptTimeout,
			L1E_MIN_L1SYNC_RECEIPT_TIMEOUT,L1E_MAX_L1SYNC_RECEIPT_TIMEOUT),
    INST_OPTION_BOOL("l1SyncEnabled", cfg.l1SyncEnabled),
    INST_OPTION_BOOL("l1SyncRxCoherencyIsRequired", cfg.l1SyncRxCoherencyIsRequired),
    INST_OPTION_BOOL("l1SyncTxCoherencyIsRequired", cfg.l1SyncTxCoherencyIsRequired),
    INST_OPTION_BOOL("l1SyncCongruencyIsRequired", cfg.l1SyncCongruencyIsRequired),
    INST_OPTION_BOOL("l1SyncOptParamsEnabled", cfg.l1SyncOptParamsEnabled),
    INST_OPTION_BOOL("l1SyncTimestampsCorrectedTxEnabled", cfg.l1SyncOptParamsTimestampsCorrectedTx),
#endif

	INST_OPTION_BOOL("asymmetryCorrectionEnable", cfg.asymmetryCorrectionEnable),
	INST_OPTION_INT64_RANGE("constantAsymmetry", ARG_INT64, NULL,cfg.constantAsymmetry_ps,
			TIME_INTERVAL_MIN_PICOS_VALUE_AS_INT64,TIME_INTERVAL_MAX_PICOS_VALUE_AS_INT64),

	INST_OPTION_INT("desiredState", ARG_NAMES, arg_states, cfg.desiredState),
	INST_OPTION_INT64_RANGE("egressLatency", ARG_INT64, NULL,cfg.egressLatency_ps,
			TIME_INTERVAL_MIN_PICOS_VALUE_AS_INT64,TIME_INTERVAL_MAX_PICOS_VALUE_AS_INT64),
	INST_OPTION_INT64_RANGE("ingressLatency", ARG_INT64, NULL,cfg.ingressLatency_ps,
			TIME_INTERVAL_MIN_PICOS_VALUE_AS_INT64,TIME_INTERVAL_MAX_PICOS_VALUE_AS_INT64),
	INST_OPTION_INT64_RANGE("scaledDelayCoefficient", ARG_INT64, NULL,cfg.scaledDelayCoefficient,
			PP_MIN_DELAY_COEFFICIENT_AS_RELDIFF,PP_MAX_DELAY_COEFFICIENT_AS_RELDIFF),
	INST_OPTION_DOUBLE_RANGE("delayCoefficient", ARG_DOUBLE, NULL,cfg.delayCoefficient,
			PP_MIN_DELAY_COEFFICIENT_AS_DOUBLE,PP_MAX_DELAY_COEFFICIENT_AS_DOUBLE),
	RT_OPTION_INT_RANGE("clock-class", ARG_INT, NULL, clock_quality_clockClass,
			PP_MIN_CLOCK_CLASS,PP_MAX_CLOCK_CLASS),
	RT_OPTION_INT_RANGE("clock-accuracy", ARG_INT, NULL,clock_quality_clockAccuracy,
			PP_MIN_CLOCK_ACCURACY,PP_MAX_CLOCK_ACCURACY),
	RT_OPTION_INT_RANGE("clock-allan-variance", ARG_INT, NULL,clock_quality_offsetScaledLogVariance,
			PP_MIN_CLOCK_VARIANCE,PP_MAX_CLOCK_VARIANCE),
	RT_OPTION_INT_RANGE("time-source", ARG_INT, NULL, timeSource,
				PP_MIN_TIME_SOURCE,PP_MAX_TIME_SOURCE),
	RT_OPTION_INT_RANGE("domain-number", ARG_INT, NULL, domainNumber,
			PP_MIN_DOMAIN_NUMBER,PP_MAX_DOMAIN_NUMBER),
	RT_OPTION_INT_RANGE("priority1", ARG_INT, NULL, priority1,
			PP_MIN_PRIORITY1, PP_MAX_PRIORITY1),
	RT_OPTION_INT_RANGE("priority2", ARG_INT, NULL, priority2,
			PP_MIN_PRIORITY2, PP_MAX_PRIORITY2),
	RT_OPTION_INT_RANGE("ptpPpsThresholdMs", ARG_INT, NULL, ptpPpsThresholdMs,
			PP_MIN_PTP_PPSGEN_THRESHOLD_MS, PP_MAX_PTP_PPSGEN_THRESHOLD_MS),
	RT_OPTION_INT_RANGE("gmDelayToGenPpsSec", ARG_INT, NULL, gmDelayToGenPpsSec,
			PP_MIN_GM_DELAY_TO_GEN_PPS_SEC, PP_MAX_GM_DELAY_TO_GEN_PPS_SEC),
#if !CONFIG_HAS_CODEOPT_EPC_ENABLED && !CONFIG_HAS_CODEOPT_SO_ENABLED
	RT_OPTION_BOOL("externalPortConfigurationEnabled",externalPortConfigurationEnabled),
	RT_OPTION_BOOL("slaveOnly",slaveOnly),
#else
#if CONFIG_HAS_CODEOPT_EPC_ENABLED
	RT_OPTION_BOOL_TRUE("externalPortConfigurationEnabled",externalPortConfigurationEnabled),
	RT_OPTION_BOOL_FALSE("slaveOnly",slaveOnly),
#endif
#if CONFIG_HAS_CODEOPT_SO_ENABLED
	RT_OPTION_BOOL_FALSE("externalPortConfigurationEnabled",externalPortConfigurationEnabled),
	RT_OPTION_BOOL_TRUE("slaveOnly",slaveOnly),
#endif
#endif
	RT_OPTION_BOOL("forcePpsGen",forcePpsGen),
	RT_OPTION_BOOL("ptpFallbackPpsGen",ptpFallbackPpsGen),
	{}
};

static struct pp_argline * pp_arglines[] = {
		pp_global_arglines,
		pp_arch_arglines,
		NULL
};

/* local implementation of isblank() and isdigit() for bare-metal users */
static int blank(int c)
{
	return c == ' '  || c == '\t' || c == '\n';
}

static int digit(char c)
{
	return (('0' <= c) && (c <= '9'));
}

static char *first_word(char *line, char **rest)
{
	char *ret;
	int l = strlen(line) -1;

	/* remove trailing blanks */
	while (l >= 0 && blank(line[l]))
		line [l--] = '\0';

	/* skip leading blanks to find first word */
	while (*line && blank(*line))
		line++;
	ret = line;
	/* find next blank and thim there*/
	while (*line && !blank(*line))
		line++;
	if (*line) {
		*line = '\0';
		line++;
	}
	*rest = line;
	return ret;
}

static int word_in_list(char *word, char *list) {
	char listCopy[64];
	char *next,*curr;

	if ( strlen(list) > sizeof(listCopy)-1) {
		pp_error("%s: List string too big (%u)\n", __func__,
			 (unsigned)strlen(list));
		return 0;
	}
	strcpy(listCopy, list);
	next=listCopy;
	while ( *next ) {
		if ( (curr=first_word(next, &next))!=NULL ) {
			if ( strcmp(curr,word)==0)
				return 1;
		}
	}
	return 0;
}


static int parse_time(struct pp_cfg_time *ts, char *s)
{
	long sign = 1;
	long num;
	int i;

	/* skip leading blanks */
	while (*s && blank(*s))
		s++;
	/* detect sign */
	if (*s == '-') {
		sign = -1;
		s++;
	} else if (*s == '+') {
		s++;
	}

	if (!*s)
		return -1;

	/* parse integer part */
	num = 0;
	while (*s && digit(*s)) {
		num *= 10;
		num += *s - '0';
		s++;
	}

	ts->tv_sec = sign * num;
	ts->tv_nsec = 0;

	if (*s == '\0')
		return 0; // no decimals
	// else
	if (*s != '.')
		return -1;

	/* parse decimals */
	s++; // skip '.'
	num = 0;
	for (i = 0; (i < 9) && *s && digit(*s); i++) {
		num *= 10;
		num += *s - '0';;
		s++;
	}
	if (*s) // more than 9 digits or *s is not a digit
		return -1;
	for (; i < 9; i++) // finish to scale nanoseconds
		num *=10;
	ts->tv_nsec = sign * num;
	return 0;
}

/**
 * Remove leading and trailing unexpected characters in a string
 * Returns ta pointer to the first non whitespace character in the string
 * and replace trailing whitespace with '\0'. NULL is returned if the string is empty.
 */
static char *trim(char *str) {
	int len = strlen(str);
	char *p=str;

	while( len && blank(str[len - 1])) len--; // Remove trailing unexpected characters
	while( *p && blank(*p)) p++; // remove leading unexpected characters
	return *p ? p : NULL ;
}

static int pp_config_line(struct pp_globals *ppg, char *line, int lineno)
{
	union pp_cfg_arg cfg_arg;
	struct pp_argline *l;
	struct pp_argname *n;
	char *word;
	int i;

	pp_diag(NULL, config, 2, "parsing line %i: \"%s\"\n", lineno, line);
	word = first_word(line, &line);
	/* now line points to the next word, with no leading blanks */

	if (word[0] == '#')
		return 1;
	if (!*word) {
		/* empty or blank-only
		 * FIXME: this sets cur_ppi_n to an unvalid value. this means
		 * that every blank line in config file unsets the current
		 * pp_instance being configured. For this reason after a blank
		 * line in config file the pp_instance to be configured needs to
		 * be stated anew. Probably this is a desired feature because
		 * this behavior was already present here with the previous
		 * implementation, based on pointers. Is this sane? This means
		 * configuration file is somehow indentation-dependent (because
		 * presence or absence of blank lines matters). This feature is
		 * not documented anywhere AFAIK. If it's a feature it should
		 * be. If its a bug it should be fixed.
		 */
		ppg->cfg.cur_ppi_n = -1;
		return 0;
	}

	/* Look for the configuration keyword in global, arch, ext */

	for ( i=0; ;) {
		if ( !(l=pp_arglines[i++] )) {
			pp_error("line %i: no such keyword \"%s\"\n", lineno, word);
			return -1;
		}
		while (l->f ) {
			if ( word_in_list(word, l->keyword) )
					goto keyword_found;
			l++;
		}
	}
	keyword_found:

	line=trim(line);
	if ((l->t != ARG_NONE) && !line) {
		pp_error("line %i: no argument for option \"%s\"\n", lineno,
									word);
		return -1;
	}

	switch(l->t) {

	case ARG_NONE:
		break;

	case ARG_INT:
		if (sscanf(line, "%i", &(cfg_arg.i)) != 1) {
			pp_error("line %i: \"%s\": not int\n", lineno, word);
			return -1;
		}
		break;

	case ARG_INT64:
		if (sscanf(line, "%" SCNd64, &(cfg_arg.i64)) != 1) {
			pp_error("line %i: \"%s\"[%s]: not int64\n", lineno, word,line);
			return -1;
		}
		break;

	case ARG_INT2:
		if (sscanf(line, "%i,%i", cfg_arg.i2, &cfg_arg.i2[1]) < 0) {
			pp_error("line %i: wrong arg \"%s\" for \"%s\"\n",
				 lineno, line, word);
			return -1;
		}
		break;

	case ARG_DOUBLE:
		if (sscanf(line, "%lf", &cfg_arg.d) < 0) {
			pp_error("line %i: wrong arg \"%s\" for \"%s\"\n",
				 lineno, line, word);
			return -1;
		}
		break;
	case ARG_STR:
		cfg_arg.s = line;
		break;

	case ARG_NAMES:
		for (n = l->args; n->name; n++)
			 if ( word_in_list(line, n->name) )
				 break;
		if (!n->name) {
			pp_error("line %i: wrong arg \"%s\" for \"%s\"\n",
				 lineno, line, word);
			return -1;
		}
		cfg_arg.i = n->value;
		break;

	case ARG_TIME:
		if(parse_time(&cfg_arg.ts, line)) {
			pp_error("line %i: wrong arg \"%s\" for \"%s\"\n",
				 lineno, line, word);
			return -1;
		}
		break;
	}

	if (l->f(l, lineno, ppg, &cfg_arg))
		return -1;

	return 0;
}

/* Parse a whole string by splitting lines at '\n' or ';' */
static int pp_parse_conf(struct pp_globals *ppg, char *conf, int len)
{
	int ret, in_comment = 0, errcount = 0;
	char *line, *rest, term;
	int lineno = 1;

	line = conf;
	/* clear current ppi, don't store current ppi across different
	 * configuration files or strings */
	ppg->cfg.cur_ppi_n = -1;
	/* parse config */
	do {
		for (rest = line;
		     *rest && *rest != '\n' && *rest != ';'; rest++)
			;
		term = *rest;
		*rest = '\0';
		ret = 0;
		if (!in_comment) {
			if (*line)
				ret = pp_config_line(ppg, line, lineno);
			if (ret == 1)
				in_comment = 1;
			if (ret < 0)
				errcount++;
		}

		line = rest + 1;
		if (term == '\n') {
			lineno++;
			in_comment = 0;
		}
	} while (term); /* if terminator was already 0, we are done */
	return errcount ? -1 : 0;
}

/* Open a file, warn if not found */
static int pp_open_conf_file(char *name)
{
	int fd;

	if (!name)
		return -1;
	fd = open(name, O_RDONLY);
	if (fd >= 0) {
		pp_printf("Using config file %s\n", name);
		return fd;
	}
	pp_printf("Warning: %s: %s\n", name, strerror(errno));
	return -1;
}

/*
 * This is one of the public entry points, opening a file
 *
 * "force" means that the called wants to open *this file.
 * In this case we count it even if it fails, so the default
 * config file is not used
 */
int pp_config_file(struct pp_globals *ppg, int force, char *fname)
{
	int conf_fd, i, conf_len = 0;
	int r = 0, next_r;
	struct stat conf_fs;
	char *conf_buf;

	conf_fd = pp_open_conf_file(fname);
	if (conf_fd < 0) {
		if (force)
			ppg->cfg.cfg_items++;
		return -1;
	}
	ppg->cfg.cfg_items++;

	/* read the whole file, it is split up later on */

	fstat(conf_fd, &conf_fs);
	conf_buf = calloc(1, conf_fs.st_size + 2);

	do {
		next_r = conf_fs.st_size - conf_len;
		r = read(conf_fd, &conf_buf[conf_len], next_r);
		if (r <= 0)
			break;
		conf_len = strlen(conf_buf);
	} while (conf_len < conf_fs.st_size);
	close(conf_fd);

	i = pp_parse_conf(ppg, conf_buf, conf_len);
	free(conf_buf);
	return i;
}

/*
 * This is the other public entry points, opening a file
 */
int pp_config_string(struct pp_globals *ppg, char *s)
{
	return pp_parse_conf(ppg, s, strlen(s));
}

