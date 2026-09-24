/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __ENDIANNESS_H__
#define __ENDIANNESS_H__

#include <stdint.h>

/* Old gcc compilers don't provide __BYTE_ORDER__.
   We use such an old compiler for lm32. */
#ifndef __BYTE_ORDER__
# define __ORDER_LITTLE_ENDIAN__ 1234
# define __ORDER_BIG_ENDIAN__ 4321
# ifdef __lm32__
#  define __BYTE_ORDER__ __ORDER_BIG_ENDIAN__
# else
#  error "Unknown architecture (for old compiler)"
# endif
#endif

/* Declare those functions as inline (and not as macro) so that they have
   an address (but only once).  */

#define ntohl  htonl
#define ntohs  htons

#define le16_to_host host_to_le16
#define le32_to_host host_to_le32
#define be16_to_host host_to_be16
#define be32_to_host host_to_be32

#ifndef __PPSI_LIB_H__
/* ppsi/lib.h also declares htonll.  */
#define ntohll  htonll

static inline uint64_t htonll(uint64_t hostllong)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	return __builtin_bswap64(hostllong);
#else
	return hostllong;
#endif
}
#endif

static inline uint32_t htonl(uint32_t hostlong)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	return __builtin_bswap32(hostlong);
#else
	return hostlong;
#endif
}

static inline uint16_t htons(uint16_t hostshort)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	return __builtin_bswap16(hostshort);
#else
	return hostshort;
#endif
}

#define htonl_mem(mem, size) ntohl_mem(mem, size)

/* Change endianess on a memory region */
static inline void ntohl_mem(uint8_t *mem, int size_bytes)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	int i;

	for (i = 0; i < size_bytes ; i += sizeof(uint32_t)) {
		*(uint32_t*)(mem + i) = ntohl(*(uint32_t*)(mem + i));
	}
#endif
}

static inline uint32_t be32_to_host(uint32_t hostlong)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	return __builtin_bswap32(hostlong);
#else
	return hostlong;
#endif
}

static inline uint32_t le32_to_host(uint32_t hostlong)
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	return __builtin_bswap32(hostlong);
#else
	return hostlong;
#endif
}

static inline uint16_t be16_to_host(uint16_t hostshort)
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	return __builtin_bswap16(hostshort);
#else
	return hostshort;
#endif
}

static inline uint16_t le16_to_host(uint16_t hostshort)
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	return __builtin_bswap32(hostshort);
#else
	return hostshort;
#endif
}

#endif /* ENDIANNESS_H__ */
