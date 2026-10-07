#ifndef __WRC_GLOBAL_H
#define __WRC_GLOBAL_H
#include <lib/ipv4.h>
#include <dev/minic.h>

#define WRC_G_MAGIC 0xADA5301E
#define WRC_G_VERSION 1

#define WRC_G_LINK_VERSION 1

struct wrc_global_link {
	uint32_t version;
	char wrc_hw_name[HW_NAME_LENGTH];
	uint16_t vlan;
	unsigned char link_up;
	enum ip_status_t ip_state;
	uint8_t ip_addr[INET_ALEN];
	uint8_t mac_addr[ETH_ALEN];
};

struct wrc_global {
	uint32_t magic;
	uint32_t version;
	struct wrc_global_link *global_link;
	int task_list_max;
	struct wrc_task *task_list;
	int temp_group_list_max;
	struct wrc_temp_group *temp_group_list;
	volatile struct softpll_state *softpll;
	struct spll_fifo_log *pll_fifo;
	struct sfp_info *sfp_info;
	void * config;
};

extern struct wrc_global_link wrc_global_link;
extern const struct wrc_global wrc_global;

#define link_status wrc_global_link.link_up
#define wrc_vlan_number wrc_global_link.vlan
#define ip_status wrc_global_link.ip_state

#endif
