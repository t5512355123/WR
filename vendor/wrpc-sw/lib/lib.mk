obj-y += \
	lib/util.o \
	lib/wrc-tasks.o \
	lib/assert.o \
	lib/usleep.o \
	lib/event.o

obj-$(CONFIG_WRPC_PPSI) += \
	lib/events-ptp.o \

obj-$(CONFIG_EMBEDDED_NODE) += lib/task-diags.o lib/task-stats.o

obj-$(CONFIG_WR_NODE) += lib/net.o

obj-$(CONFIG_IP) += lib/ipv4.o lib/arp.o lib/icmp.o lib/udp.o lib/bootp.o
obj-$(CONFIG_SYSLOG) += lib/syslog.o
obj-$(CONFIG_LATENCY_PROBE) += lib/latency.o
obj-$(CONFIG_SNMP) += lib/snmp.o
obj-$(CONFIG_LLDP) += lib/lldp.o
obj-$(CONFIG_NETCONSOLE) += lib/netconsole.o
# obj-$(CONFIG_TARGET_ERTM14) += lib/ertm14-uart-link.o
