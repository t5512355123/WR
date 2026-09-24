#ifndef __WRAPPED_INTTYPES_H
#define __WRAPPED_INTTYPES_H

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
#ifndef _UINT32_T_DECLARED
typedef unsigned int uint32_t;
#define _UINT32_T_DECLARED
#endif
typedef unsigned long long uint64_t;

typedef signed char int8_t;
typedef signed short int16_t;
#ifndef _INT32_T_DECLARED
typedef signed int int32_t;
#define _INT32_T_DECLARED
#endif
typedef signed long long int64_t;

#ifndef _INTPTR_T_DECLARED
typedef unsigned long intptr_t;
#define _INTPTR_T_DECLARED
#endif

#define UINT32_MAX 4294967295U

/* gcc 4.5.3 used for wrpc does not have these */
#ifndef INT64_MIN
# define INT64_MIN	(-9223372036854775807LL-1)
#endif

#ifndef INT64_MAX
# define INT64_MAX	(9223372036854775807LL)
#endif

/* printf formats
 * Copied form gcc's inttypes.h */

#define __STRINGIFY(a)	#a
/* 32-bit types */
#define __PRI32(x) __STRINGIFY(x)
#define __SCN32(x) __STRINGIFY(x)

#define PRId32		__PRI32(d)
#define PRId32		__PRI32(d)
#define PRIi32		__PRI32(i)
#define PRIo32		__PRI32(o)
#define PRIu32		__PRI32(u)
#define PRIx32		__PRI32(x)
#define PRIX32		__PRI32(X)

#define SCNd32		__SCN32(d)
#define SCNi32		__SCN32(i)
#define SCNo32		__SCN32(o)
#define SCNu32		__SCN32(u)
#define SCNx32		__SCN32(x)

/* 64-bit types */
#define __PRI64(x) __STRINGIFY(ll##x)
#define __SCN64(x) __STRINGIFY(ll##x)

#define PRId64		__PRI64(d)
#define PRIi64		__PRI64(i)
#define PRIo64		__PRI64(o)
#define PRIu64		__PRI64(u)
#define PRIx64		__PRI64(x)
#define PRIX64		__PRI64(X)

#define SCNd64		__SCN64(d)
#define SCNi64		__SCN64(i)
#define SCNo64		__SCN64(o)
#define SCNu64		__SCN64(u)
#define SCNx64		__SCN64(x)

#endif
