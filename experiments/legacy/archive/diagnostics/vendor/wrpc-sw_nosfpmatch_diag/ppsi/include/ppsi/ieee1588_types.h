/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released to the public domain
 */

/* Structs defined in IEEE Std 1588-2008 */

#ifndef __PPSI_IEEE_1588_TYPES_H__
#define __PPSI_IEEE_1588_TYPES_H__

#include <stdint.h>
#include <ppsi/pp-time.h>

/* See F.2, pag.223 */
#define PP_ETHERTYPE	0x88f7

enum {FALSE=0, TRUE};
typedef uint8_t		Boolean;
typedef uint8_t		Octet;
typedef int8_t		Integer8;
typedef int16_t		Integer16;
typedef int32_t		Integer32;
typedef int64_t		Integer64;
typedef uint8_t		UInteger8;
typedef uint16_t	UInteger16;
typedef uint32_t	UInteger32;
typedef uint64_t	UInteger64;
/* Enumerations are unsigned, see 5.4.2, page 15 */
typedef uint16_t	Enumeration16;
typedef uint8_t		Enumeration8;
typedef uint8_t		Enumeration4;
typedef uint8_t		UInteger4;
typedef uint8_t		Nibble;

/* FIXME: each struct must be aligned for lower memory usage */

typedef struct UInteger48 {
	uint32_t	lsb;
	uint16_t	msb;
} UInteger48;

typedef struct _Integer64 { /* TODO : Should be replaced by Integer64 */
	uint32_t	lsb;
	int32_t		msb;
} _Integer64;

typedef struct _UInteger64 { /*/* TODO : Should be replaced by UInteger64 */
	uint32_t	lsb;
	uint32_t	msb;
} _UInteger64;

/* Page 19 :the time interval is expressed in units of nanoseconds and multiplied by 2 +16 */
#define TIME_INTERVAL_FRACBITS 16
#define TIME_INTERVAL_FRACMASK 0xFFFF
#define TIME_INTERVAL_FRACBITS_AS_FLOAT 16.0
#define TIME_INTERVAL_ROUNDING_VALUE ((uint64_t)1<<(TIME_INTERVAL_FRACBITS-1))

/* Min/max value expressed in picos (int64_t) which can be stored in a TimeInterval type */
#define TIME_INTERVAL_MIN_PICOS_VALUE_AS_INT64 ((int64_t) 0xFE0C000000000000)
#define TIME_INTERVAL_MAX_PICOS_VALUE_AS_INT64 ((int64_t) 0x1F3FFFFFFFFFC18)

typedef Integer64 TimeInterval;

/* White Rabbit extension */
typedef struct FixedDelta {
	_UInteger64	scaledPicoseconds;
} FixedDelta;

typedef struct Timestamp { /* page 13 (33) -- no typedef expected */
	UInteger48	secondsField;
	UInteger32	nanosecondsField;
} Timestamp;

/** ******************* IEEE1588-2019 **************************************/
#define REL_DIFF_FRACBITS 62
#define REL_DIFF_FRACBITS_AS_FLOAT 62.0
#define REL_DIFF_TWO_POW_FRACBITS  ((double)4.611686018427388E18) /* double value returned by pow(2.0,62.0) */
#define REL_DIFF_FRACMASK 0x3fffffffffffffff

/* Min/max values for  RelativeDifference type */
#define RELATIVE_DIFFERENCE_MIN_VALUE  INT64_MIN
#define RELATIVE_DIFFERENCE_MAX_VALUE  INT64_MAX
#define RELATIVE_DIFFERENCE_MIN_VALUE_AS_DOUBLE  -2.0
#define RELATIVE_DIFFERENCE_MAX_VALUE_AS_DOUBLE  1.9999999999999989

/*draft P1588_v_29: page 17*/
/* The scaledRelativeDifference member is the relative difference expressed
 * as a dimensionless fraction and multiplied by 2^+62, with any remaining
 * fractional part truncated. */
typedef Integer64 RelativeDifference;


typedef struct ClockIdentity { /* page 13 (33) */
	Octet id[8];
} ClockIdentity;
#define PP_CLOCK_IDENTITY_LENGTH	sizeof(ClockIdentity)

typedef struct PortIdentity { /* page 13 (33) */
	ClockIdentity	clockIdentity;
	UInteger16	portNumber;
} PortIdentity;

typedef struct PortAdress { /* page 13 (33) */
	Enumeration16	networkProtocol;
	UInteger16	adressLength;
	Octet		*adressField;
} PortAdress;

typedef struct ClockQuality { /* page 14 (34) */
	UInteger8	 clockClass;
	Enumeration8 clockAccuracy;
	UInteger16 	 offsetScaledLogVariance;
} ClockQuality;

struct TLV { /* page 14 (34) -- never used */
	Enumeration16	tlvType;
	UInteger16	lengthField;
	Octet		*valueField;
};

#define TLV_TYPE_ORG_EXTENSION	    0x0003 /* organization specific */
#define TLV_TYPE_L1_SYNC            0x8001u

struct PTPText { /* page 14 (34) -- never used */
	UInteger8	lengthField;
	Octet		*textField;
};

struct FaultRecord { /* page 14 (34) -- never used */
	UInteger16	faultRecordLength;
	Timestamp	faultTime;
	Enumeration8	severityCode;
	struct PTPText	faultName;
	struct PTPText	faultValue;
	struct PTPText	faultDescription;
};


/* Common Message header (table 18, page 124) */
typedef struct MsgHeader {
	Nibble		transportSpecific;
	Enumeration4	messageType;
	UInteger4	versionPTP;
	UInteger16	messageLength;
	UInteger8	domainNumber;
	Octet		flagField[2];
	struct pp_time	cField;
	PortIdentity	sourcePortIdentity;
	UInteger16	sequenceId;
	/* UInteger8	controlField; -- receiver must ignore it */
	Integer8	logMessageInterval;
} MsgHeader;

/* Announce Message (table 25, page 129) */
typedef struct MsgAnnounce {
	struct pp_time	originTimestamp;
	Integer16	currentUtcOffset;
	UInteger8	grandmasterPriority1;
	ClockQuality	grandmasterClockQuality;
	UInteger8	grandmasterPriority2;
	ClockIdentity	grandmasterIdentity;
	UInteger16	stepsRemoved;
	Enumeration8	timeSource;
	UInteger16      ext_specific[4]; /* Extension specific. Must be  UInteger16 to align it in the structure*/
} MsgAnnounce;

/* Sync Message (table 26, page 129) */
typedef struct MsgSync {
	struct pp_time originTimestamp;
} MsgSync;

/* DelayReq Message (table 26, page 129) */
typedef struct MsgDelayReq {
	struct pp_time	originTimestamp;
} MsgDelayReq;

/* DelayResp Message (table 27, page 130) */
typedef struct MsgFollowUp {
	struct pp_time	preciseOriginTimestamp;
} MsgFollowUp;


/* DelayResp Message (table 28, page 130) */
typedef struct MsgDelayResp {
	struct pp_time	receiveTimestamp;
	PortIdentity	requestingPortIdentity;
} MsgDelayResp;

/* PdelayReq Message (table 29, page 131) */
typedef struct MsgPDelayReq {
	struct pp_time	originTimestamp;
} MsgPDelayReq;

/* PdelayResp Message (table 30, page 131) */
typedef struct MsgPDelayResp {
	struct pp_time	requestReceiptTimestamp;
	PortIdentity	requestingPortIdentity;
} MsgPDelayResp;

/* PdelayRespFollowUp Message (table 31, page 132) */
typedef struct MsgPDelayRespFollowUp {
	struct pp_time	responseOriginTimestamp;
	PortIdentity	requestingPortIdentity;
} MsgPDelayRespFollowUp;

/* Signaling Message (Table 51 : Signaling message fields) */
typedef struct MsgSignaling {
	PortIdentity	targetPortIdentity;
	char		*tlv;
} MsgSignaling;

/* Management Message (table 37, page 137) */
typedef struct {
	PortIdentity	targetPortIdentity;
	UInteger8	startingBoundaryHops;
	UInteger8	boundaryHops;
	Enumeration4	actionField;
	char		*tlv;
} MsgManagement;

/* Default Data Set */
typedef struct {		/* 1588-2019 8.2.1.1, page 113 */
	/* Static */
	ClockIdentity	clockIdentity;
	UInteger16	numberPorts;
	/* Dynamic */
	ClockQuality	clockQuality;
	/* Configurable */
	UInteger8	priority1;
	UInteger8	priority2;
	UInteger8	domainNumber;
	Boolean		slaveOnly;
	/** Optional (IEEE1588-2019) */
	Timestamp	currentTime;               /* 1588-2019 8.2.1.5.1 */
	Boolean		instanceEnable;            /* 1588-2019 8.2.1.5.2 */
	Boolean	        externalPortConfigurationEnabled; /* 1588-2019 8.2.1.5.3 */
	Enumeration8	maxStepsRemoved;           /* 1588-2019 8.2.1.5.4 */
	Enumeration8	instanceType;              /* 1588-2019 8.2.1.5.5 */
	/** *********************** */
} defaultDS_t;

/* Current Data Set */
typedef struct {		/* page 67 */
	/* Dynamic */
	UInteger16	stepsRemoved;
	TimeInterval	offsetFromMaster; /* page 112 */
	TimeInterval	meanDelay; /* page 112 : one Way Delay */
} currentDS_t;

/* Parent Data Set */
typedef struct  {		/* page 68 */
	/* Dynamic */
	PortIdentity	parentPortIdentity;
	/* Boolean	parentStats; -- not used */
	UInteger16	observedParentOffsetScaledLogVariance;
	Integer32	observedParentClockPhaseChangeRate;
	ClockIdentity	grandmasterIdentity;
	ClockQuality	grandmasterClockQuality;
	UInteger8	grandmasterPriority1;
	UInteger8	grandmasterPriority2;
	/* Private data */
	Boolean newGrandmaster;
} parentDS_t;

/* Port Data set */
typedef struct  {			/* page 72 */
	/* Static */
	PortIdentity	portIdentity;
	/* Dynamic */
	/* Enumeration8	portState; -- not used */
	Integer8	logMinDelayReqInterval; /* -- same as pdelay one */
	/* Configurable */
	Integer8	logAnnounceInterval;
	UInteger8	announceReceiptTimeout;
	Integer8	logSyncInterval;
	/* Enumeration8	delayMechanism; -- not used */
	UInteger4	versionNumber;

	void		*ext_dsport;
	/** (IEEE1588-2019) */
	Integer8	       logMinPdelayReqInterval;      /*draft P1588_v_29: page 124 */
	UInteger4	       minorVersionNumber;           /*draft P1588_v_29: page 124 */
	TimeInterval       delayAsymmetry;               /*draft P1588_v_29: page 124 */
	TimeInterval       meanLinkDelay;                /* P2P: estimation of the current one-way propagation delay */
	/** Optional: */
	Boolean		       portEnable;                   /*draft P1588_v_29: page 124 */
	Boolean		       masterOnly;                   /*draft P1588_v_29: page 124 */
	/** *********************** */
	RelativeDifference delayAsymCoeff; /* alpha/(alpha+2). Used to compute delayAsymmetry */
} portDS_t;

/* Time Properties Data Set */
typedef struct  {	/* page 70 */
	/* Dynamic */
	Integer16	currentUtcOffset;
	Boolean		currentUtcOffsetValid;
	Boolean		leap59;
	Boolean		leap61;
	Boolean		timeTraceable;
	Boolean		frequencyTraceable;
	Boolean		ptpTimescale;
	Enumeration8	timeSource;
} timePropertiesDS_t;

/** ******************* IEEE1588-2019 **************************************
 * Adding new optional data sets (DS) defined in clause, only these relevant
 * for HA
 */
typedef struct { /*draft P1588_v_29: page 118 */
	Octet		manufacturerIdentity[3];
	struct PTPText	productDescription;
	struct PTPText	productRevision;
	struct PTPText	userDescription;
} descriptionDS_t;
/* Optional, not implemented, Instance DS:
 * faultLogDS:                       draft P1588_v_29: page 93
 * nonvolatileStorageDS              draft P1588_v_29: page 94
 * pathTraceDS                       draft P1588_v_29: page 95
 * alternateTimescaleOffsetsDS       draft P1588_v_29: page 95
 * holdoverUpgradeDS                 draft P1588_v_29: page 95
 * grandmasterClusterDS              draft P1588_v_29: page 95
 * acceptableMasterTableDS           draft P1588_v_29: page 95
 * clockPerformanceMonitoringDS      draft P1588_v_29: page 95
 *
 * Optional, not implemented, port DS
 * descriptionPortDS                 draft P1588_v_29: page 99
 * unicastNegotiationDS              draft P1588_v_29: page 100
 * alternateMasterDS                 draft P1588_v_29: page 100
 * unicastDiscoveryDS                draft P1588_v_29: page 100
 * acceptableMasterPortDS            draft P1588_v_29: page 100
 * performanceMonitoringPortDS       draft P1588_v_29: page 101
 *
 * For Transparent Clocks, not implemented
 * transparentClockDefaultDS		draft P1588_v_29: page 102
 * transparentClockPortDS		draft P1588_v_29: page 103
 */
typedef struct  { /*draft P1588_v_29: page 128*/
	TimeInterval egressLatency;
	TimeInterval ingressLatency;
	TimeInterval messageTimestampPointLatency;
	/* Not in specification */
	TimeInterval semistaticLatency;
} timestampCorrectionPortDS_t;

typedef struct  { /*draft P1588_v_29: page129*/
	TimeInterval	constantAsymmetry;
	RelativeDifference	scaledDelayCoefficient;
	Boolean enable;
} asymmetryCorrectionPortDS_t;

typedef struct {/*draft P1588_v_29: Clause 17.6.3 */
	Enumeration8 desiredState; /* draft P1588_v_29: Clause 17.6.3.2 */
}externalPortConfigurationPortDS_t;

/** ************************************************************************/
/* Enumeration States (table 8, page 73) */
typedef enum  {
	PPS_END_OF_TABLE	= 0,
	PPS_INITIALIZING,
	PPS_FAULTY,
	PPS_DISABLED,
	PPS_LISTENING,
	PPS_PRE_MASTER,
	PPS_MASTER,
	PPS_PASSIVE,
	PPS_UNCALIBRATED,
	PPS_SLAVE,
#ifdef CONFIG_ABSCAL
	PPS_ABSCAL,  /* not standard */
#endif
	PPS_LAST_STATE /* unused */
}pp_std_states;

typedef enum  {
	PPM_SYNC		= 0x0,
	PPM_DELAY_REQ,
	PPM_PDELAY_REQ,
	PPM_PDELAY_RESP,
	PPM_FOLLOW_UP		= 0x8,
	PPM_DELAY_RESP,
	PPM_PDELAY_R_FUP,
	PPM_ANNOUNCE,
	PPM_SIGNALING,
	PPM_MANAGEMENT,
	__PP_NR_MESSAGES_TYPES,
	/* NO_MESSAGE means "no message received", or "eaten by hook" */
	PPM_NO_MESSAGE,

	PPM_NOTHING_TO_DO	= 0x100, /* for hooks.master_msg() */
}pp_std_messages;

/* Enumeration Domain Number (table 2, page 41) */
enum ENDomainNumber {
	DFLT_DOMAIN_NUMBER	= 0,
	ALT1_DOMAIN_NUMBER,
	ALT2_DOMAIN_NUMBER,
	ALT3_DOMAIN_NUMBER
};

/* Enumeration Network Protocol (table 3, page 46) */
enum ENNetworkProtocol {
	UDP_IPV4	= 1,
	UDP_IPV6,
	IEEE_802_3,
	DeviceNet,
	ControlNet,
	PROFINET
};

/* Enumeration Time Source (table 7, page 57) */
enum ENTimeSource {
	TIME_SRC_MIN_VALUE          = 0x10,
	TIME_SRC_ATOMIC_CLOCK		= 0x10,
	TIME_SRC_GNSS			    = 0x20,
	TIME_SRC_TERRESTRIAL_RADIO	= 0x30,
	TIME_SRC_SERIAL_TIME_CODE	= 0x39,
	TIME_SRC_PTP			    = 0x40,
	TIME_SRC_NTP			    = 0x50,
	TIME_SRC_HAND_SET		    = 0x60,
	TIME_SRC_OTHER			    = 0x90,
	TIME_SRC_INTERNAL_OSCILLATOR= 0xA0,
	TIME_SRC_MAX_VALUE          = 0xFF
};

/* Enumeration Delay mechanism (table 21, page 126) */
enum ENDelayMechanism {
	MECH_E2E		= 1,
	MECH_P2P		= 2,
	MECH_MAX_SUPPORTED	= 2,
	MECH_COMMON_P2P		= 3,
	MECH_SPECIAL		= 4,
	MECH_NO_MECHANISM	= 0xFE
};

/* clockAccuracy enumeration (table 5) */
enum ENClockAccuracy {
	CLOCK_ACCURACY_MIN_VALUE=0,
	CLOCK_ACCURACY_1PS	= 0x17,
	CLOCK_ACCURACY_2_5_PS,
	CLOCK_ACCURACY_10_PS,
	CLOCK_ACCURACY_25_PS,
	CLOCK_ACCURACY_100_PS,
	CLOCK_ACCURACY_250_PS,
	CLOCK_ACCURACY_1_NS,
	CLOCK_ACCURACY_2_5_NS,
	CLOCK_ACCURACY_10_NS,
	CLOCK_ACCURACY_25_NS,
	CLOCK_ACCURACY_100_NS,
	CLOCK_ACCURACY_250_NS,
	CLOCK_ACCURACY_1_US,
	CLOCK_ACCURACY_2_5_US,
	CLOCK_ACCURACY_10_US,
	CLOCK_ACCURACY_25_US,
	CLOCK_ACCURACY_100_US,
	CLOCK_ACCURACY_250_US,
	CLOCK_ACCURACY_1_MS,
	CLOCK_ACCURACY_2_5_MS,
	CLOCK_ACCURACY_10_MS,
	CLOCK_ACCURACY_25_MS,
	CLOCK_ACCURACY_100_MS,
	CLOCK_ACCURACY_250_MS,
	CLOCK_ACCURACY_1_S,
	CLOCK_ACCURACY_10_S,
	CLOCK_ACCURACY_GREATER_10_S,
	CLOCK_ACCURACY_UNKNOWN		= 0xFE,
	CLOCK_ACCURACY_MAX_VALUE
};

#endif /* __PPSI_IEEE_1588_TYPES_H__ */
