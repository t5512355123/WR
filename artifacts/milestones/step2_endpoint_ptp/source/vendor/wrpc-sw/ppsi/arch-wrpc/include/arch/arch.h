#ifndef __ARCH_H__
#define __ARCH_H__
#include <assert.h> /* wrpc-sw includes assert already */

/* don't include for host tools */
#ifndef BUILD_HOST
#include <endianness.h>
#endif

#define abs(x) ((x >= 0) ? x : -x)

int wrc_ptp_is_abscal(void);

#endif /* __ARCH_H__ */
