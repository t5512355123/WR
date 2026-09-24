#include <linux/limits.h>
#include <libudev.h>
#include <stdio.h>
#include <string.h>

#define SILICON_LABS_ID		"10c4"
#define CP2108_UART_TO_USB	"ea71"

struct sl_cp2108_port {
	char	devnode[PATH_MAX];
	char	symlink[PATH_MAX];
	int	port;
} sl_cp2108_port[4];

static int ertm_search_dongle(char *vendor_id, char *device_id,
	struct sl_cp2108_port *ports_info)
{
    struct udev *udev = udev_new();
    struct udev_enumerate *enumerate = udev_enumerate_new(udev);
    struct udev_list_entry *devs, *ptr;
    int found_ports = 0;

    udev_enumerate_add_match_subsystem(enumerate, "tty");
    udev_enumerate_add_match_property(enumerate, "ID_VENDOR_ID", vendor_id);
    udev_enumerate_add_match_property(enumerate, "ID_MODEL", device_id);
    udev_enumerate_scan_devices(enumerate);

    devs = udev_enumerate_get_list_entry(enumerate);
    udev_list_entry_foreach(ptr, devs) {
        const char *path = udev_list_entry_get_name(ptr);
        struct udev_device *dev = udev_device_new_from_syspath(udev, path);
	const char *devnode = udev_device_get_devnode(dev);

	if (devnode != NULL) {
		struct udev_list_entry *l, *links = udev_device_get_devlinks_list_entry(dev);
		int port;
		udev_list_entry_foreach(l, links) {
			const char *linkname = udev_list_entry_get_name(l);
			int i, len = strlen(linkname);
			const char *ports[]  = { "0-port0", "1-port0", "2-port0", "3-port0", };
			int trim = strlen(ports[0]);

			for (i = 0; i < 4; i++)
				if (!strcmp(ports[i], &linkname[len-trim])) {
					ports_info[i].port = port = i;
					strcpy(ports_info[i].symlink, path);
					strcpy(ports_info[i].devnode, devnode);
					goto found;
				}
			goto notfound;
		}
found:
		found_ports++;
	}
notfound:
	udev_device_unref(dev);
    }
    udev_enumerate_unref(enumerate);

    return (found_ports == 4) ? 0 : -1;
}

char *ertm_find_usb_port(void)
{
	int err;

	err = ertm_search_dongle(SILICON_LABS_ID, CP2108_UART_TO_USB, sl_cp2108_port);
	if (err < 0)
		return NULL;
	return sl_cp2108_port[2].devnode;
}

static char *functions[] = {
	"mmc15",
	"mmc14",
	"wrc",
	"wrc-console",
};

char *ertm_usb_by_function(char *func)
{
	int i;
	int err;

	err = ertm_search_dongle(SILICON_LABS_ID, CP2108_UART_TO_USB, sl_cp2108_port);
	if (err < 0)
		return NULL;
	for (i = 0; i < 4; i++)
		if (strcmp(func, functions[i]) == 0)
			return sl_cp2108_port[i].devnode;
	return NULL;
}
