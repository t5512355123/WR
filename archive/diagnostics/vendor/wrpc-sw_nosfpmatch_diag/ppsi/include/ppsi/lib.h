/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Authors: Alessandro Rubini and Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#ifndef __PPSI_LIB_H__
#define __PPSI_LIB_H__
#include <stdint.h>
#include <string.h>

extern int puts(const char *s);
extern void pp_puts(const char *s);
extern int atoi(const char *s);

extern uint32_t __div64_32(uint64_t *n, uint32_t base);

extern char *format_hex8(char *s, const unsigned char *mac);
extern char *format_mac(char *s, const unsigned char *mac);

#ifdef __lm32__
/* The lm32 compiler doesn't define __BYTE_ORDER__ (too old) */
# define PPSI_BE 1
#else
# if defined (__BYTE_ORDER__) && defined (__ORDER_LITTLE_ENDIAN__) && defined (__ORDER_BIG_ENDIAN__)
#  if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#   define PPSI_BE 0
#  else
#   define PPSI_BE 1
#  endif
# else
#  error "unsupported compiler"
# endif
#endif

#if PPSI_BE == 0
  /* Little-endian */
# ifdef CONFIG_ARCH_WRS
#  define htonll(x) htobe64(x)
#  define ntohll(x) be64toh(x)
# else
#  define htonll(x) __builtin_bswap64(x)
#  define ntohll(x) __builtin_bswap64(x)
# endif
#else
  /* Big-endian */
#  define htonll(x) (x)
#  define ntohll(x) (x)
#endif

#endif /* __PPSI_LIB_H__ */
