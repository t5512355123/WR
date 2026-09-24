/*
 * File to provide printout interfaces used in libwr of wrs-switch-sw
 */
#ifndef __WRS_MSG_H__
#define __WRS_MSG_H__

#include <ppsi/ppsi.h>
/* And shortands for people using autocompletion -- but not all levels */
#define pr_error(...)	pp_error(__VA_ARGS__)
#define pr_err(...)	pr_error(__VA_ARGS__)
#define pr_warning(...)
#define pr_warn(...)
#define pr_info(...)
#define pr_debug(...)

#endif /* __WRS_MSG_H__ */
