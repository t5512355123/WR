/*
 * This header defines structures for dumping other structures from
 * binary files. Every arch has a different endianness and alignment/size,
 * so we can't just use the structures from the host compiler. It used to
 * work for lm32/i386, but it fails with x86-64, so let's change attitude.
 */

#include <stdint.h>

/*
 * To ease copying from header files, allow int, char and other known types.
 * Please add more type as more structures are included here
 */
enum dump_type {
	dump_type_char, /* for zero-terminated strings */
	dump_type_bina, /* for binary stull in MAC format */
	/* normal types follow */
	dump_type_uint8_t,
	dump_type_uint32_t,
	dump_type_uint16_t,
	dump_type_int,
	dump_type_long_long,
	dump_type_unsigned_long,
	dump_type_unsigned_char,
	dump_type_unsigned_short,
	dump_type_double,
	dump_type_float,
	dump_type_pointer,
	dump_type_dummy,
	/* and this is ours */
	dump_type_link_up_status,
	dump_type_yes_no,
	dump_type_spll_mode,
	dump_type_ip_address,
	dump_type_ip_addr_status,
	dump_type_sfp_temp,
	dump_type_sfp_vcc,
	dump_type_sfp_tx_bias,
	dump_type_sfp_tx_pow,
	dump_type_sfp_rx_pow,
	dump_type_sfp_br_nom,
	dump_type_sfp_length1,
	dump_type_sfp_length2,
	dump_type_sfp_length3,
	dump_type_sfp_length4,
	dump_type_sfp_length5,
	dump_type_sfp_length6,
	dump_type_sfp_diag_mon_type,
	dump_type_sfp_dump_alpha,
	dump_type_sfp_dump_delta,
	dump_type_sfp_in_db,
};

/* because of the sizeof later on, we need these typedefs */
typedef void *         pointer;
typedef struct pp_time pp_time;
typedef long long      long_long;
typedef unsigned long  unsigned_long;
typedef unsigned char  unsigned_char;
typedef unsigned short unsigned_short;
typedef uint8_t        dummy; /* use the smallest */
typedef struct {unsigned char addr[4];} ip_address;
typedef uint8_t        yes_no;
typedef int            spll_mode;
typedef int            link_up_status;
typedef int            ip_addr_status;
typedef uint8_t        sfp_temp;
typedef uint8_t        sfp_vcc;
typedef uint8_t        sfp_tx_bias;
typedef uint8_t        sfp_tx_pow;
typedef uint8_t        sfp_rx_pow;
typedef uint8_t        sfp_br_nom;
typedef uint8_t        sfp_length1;
typedef uint8_t        sfp_length2;
typedef uint8_t        sfp_length3;
typedef uint8_t        sfp_length4;
typedef uint8_t        sfp_length5;
typedef uint8_t        sfp_length6;
typedef uint8_t        sfp_diag_mon_type;
typedef uint8_t        sfp_dump_alpha;
typedef uint8_t        sfp_dump_delta;
typedef uint8_t        sfp_in_db;

/*
 * This is generated with the target compiler, and then linked
 * by the host compiler, so size and alignment must be safe. Then, the
 * first structure in each group has the endian flag and the structure name.
 * Following ones have zero in endian flag and field name.
 */
#define DUMP_ENDIAN_FLAG 0x12345678
struct dump_info {
	uint32_t endian_flag;
	uint32_t type;
	uint32_t offset;
	uint32_t size;
	char name[64];
};

#define DUMP_HEADER(_struct) {			\
	.endian_flag = DUMP_ENDIAN_FLAG,	\
	.name = _struct,			\
}

/* Keep the value with the structure name. Intendeed to keep the size of
 * structure, but can be used to keep any value. */
#define DUMP_HEADER_SIZE(_struct, _size) {	\
	.endian_flag = DUMP_ENDIAN_FLAG,	\
	.name = _struct,			\
	.size = _size,		\
}

/* The macros below rely on DUMP_STRUCT that must be externally defined */
#define DUMP_FIELD(_type, _fname) {		\
	.endian_flag = 0,			\
	.type = dump_type_ ## _type,		\
	.offset = offsetof(DUMP_STRUCT, _fname),\
	.size = sizeof(_type),			\
	.name = #_fname,			\
}
#define DUMP_FIELD_SIZE(_type, _fname, _size) { \
	.endian_flag = 0,			\
	.type = dump_type_ ## _type,		\
	.offset = offsetof(DUMP_STRUCT, _fname),\
	.size = _size,				\
	.name = #_fname,			\
}


void dump_many_fields(void *addr, char *name, char *prefix);
unsigned long wrpc_get_pointer(void *base, char *s_name, char *f_name);
unsigned long wrpc_get_offset(char *s_name, char *f_name);
unsigned long wrpc_get_struct_size(char *s_name);
long long wrpc_get_64(const void *p);
long wrpc_get_l32(const void *p);
int wrpc_get_i32(const void *p);
int wrpc_get_16(const void *p);
uint8_t wrpc_get_8(const void *p);
void print_str(char *s);
