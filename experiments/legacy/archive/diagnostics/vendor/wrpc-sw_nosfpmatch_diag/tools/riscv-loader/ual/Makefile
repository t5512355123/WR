DIRS = lib tools

.PHONY: all clean install uninstall $(DIRS)

clean: TARGET = clean
install: TARGET= install
uninstall: TARGET= uninstall

all clean install uninstall: $(DIRS)

$(DIRS):
	$(MAKE) -C $@ $(TARGET)
