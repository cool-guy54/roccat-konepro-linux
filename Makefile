CC ?= cc
CFLAGS ?= -O2
CPPFLAGS ?=
WARNINGS := -std=c11 -Wall -Wextra -Werror -pedantic
LDLIBS := -lusb-1.0 -lm

PREFIX ?= /usr/local
LIBDIR ?= $(PREFIX)/lib/konepro-linux
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
UDEVDIR ?= /etc/udev/rules.d

USER_PREFIX ?= $(HOME)/.local
USER_LIBDIR := $(USER_PREFIX)/lib/konepro-linux
USER_BINDIR := $(USER_PREFIX)/bin
USER_DATADIR := $(USER_PREFIX)/share

.PHONY: all debug check clean install uninstall user-install user-uninstall \
	install-autostart uninstall-autostart install-udev uninstall-udev

all: konepro

konepro: konepro.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) $< -o $@ $(LDLIBS)

debug: CFLAGS := -O0 -g3
debug: clean konepro

check: konepro
	python3 -m py_compile konepro-gui.py
	desktop-file-validate local.konepro.Settings.desktop local.konepro.Settings-autostart.desktop

clean:
	rm -f konepro
	rm -rf __pycache__

install: konepro
	install -Dm755 konepro $(DESTDIR)$(LIBDIR)/konepro
	install -Dm755 konepro-gui $(DESTDIR)$(LIBDIR)/konepro-gui
	install -Dm755 konepro-gui.py $(DESTDIR)$(LIBDIR)/konepro-gui.py
	mkdir -p $(DESTDIR)$(BINDIR)
	ln -sfn $(LIBDIR)/konepro $(DESTDIR)$(BINDIR)/konepro
	ln -sfn $(LIBDIR)/konepro-gui $(DESTDIR)$(BINDIR)/konepro-gui
	install -Dm644 local.konepro.Settings.desktop $(DESTDIR)$(DATADIR)/applications/local.konepro.Settings.desktop

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/konepro $(DESTDIR)$(BINDIR)/konepro-gui
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -f $(DESTDIR)$(DATADIR)/applications/local.konepro.Settings.desktop

user-install: konepro
	install -Dm755 konepro $(USER_LIBDIR)/konepro
	install -Dm755 konepro-gui $(USER_LIBDIR)/konepro-gui
	install -Dm755 konepro-gui.py $(USER_LIBDIR)/konepro-gui.py
	mkdir -p $(USER_BINDIR)
	ln -sfn $(USER_LIBDIR)/konepro $(USER_BINDIR)/konepro
	ln -sfn $(USER_LIBDIR)/konepro-gui $(USER_BINDIR)/konepro-gui
	install -Dm644 local.konepro.Settings.desktop $(USER_DATADIR)/applications/local.konepro.Settings.desktop
	-update-desktop-database $(USER_DATADIR)/applications

user-uninstall: uninstall-autostart
	rm -f $(USER_BINDIR)/konepro $(USER_BINDIR)/konepro-gui
	rm -rf $(USER_LIBDIR)
	rm -f $(USER_DATADIR)/applications/local.konepro.Settings.desktop
	-update-desktop-database $(USER_DATADIR)/applications

install-autostart:
	install -Dm644 local.konepro.Settings-autostart.desktop $(HOME)/.config/autostart/local.konepro.Settings.desktop

uninstall-autostart:
	rm -f $(HOME)/.config/autostart/local.konepro.Settings.desktop

install-udev:
	install -Dm644 99-roccat-kone-pro.rules $(DESTDIR)$(UDEVDIR)/99-roccat-kone-pro.rules

uninstall-udev:
	rm -f $(DESTDIR)$(UDEVDIR)/99-roccat-kone-pro.rules
