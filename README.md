# Kone Pro for Linux

A native Linux configuration utility for the wired ROCCAT Kone Pro
(`1e7d:2c88`). It includes a dark Adwaita GUI and a command-line helper for the
mouse's onboard profiles.

## Features

- Five onboard profiles and five DPI presets per profile
- Active DPI selection from 50 to 19,000 DPI in steps of 50
- 125, 250, 500, or 1000 Hz polling per profile or across every profile
- Separate left/right RGB colors, seven effects, brightness, and effect speed
- Global 0–10 ms debounce setting
- Linux pointer, scroll, acceleration, double-click, and handedness controls
- Dark Adwaita interface with a GNOME Tweaks-style sidebar
- Strict validation and checksum checks before profile writes

Button remapping, Easy-Shift, macros, lift-off distance, angle snapping, surface
calibration, and automatic application profile switching are visible but
locked. Their Kone Pro USB reports are not publicly documented, and writing
guessed bytes could corrupt onboard profiles.

## Requirements

- A C11 compiler and `make`
- libusb 1.0 development files
- Python 3 with PyGObject
- GTK 4 and libadwaita
- `desktop-file-utils` for `make check` and desktop database refreshes
- Hyprland is optional; its pointer and scroll settings are used when available

On Arch Linux and derivatives, the required packages are typically:

```sh
sudo pacman -S --needed base-devel libusb python-gobject gtk4 libadwaita desktop-file-utils
```

## Build and test

```sh
make
make check
```

Run without installing:

```sh
./konepro-gui
```

The udev rule must be installed before a regular user can write mouse settings:

```sh
sudo make install-udev
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=1e7d --attr-match=idProduct=2c88
```

The rule grants access to members of the `input` group. Log out and back in after
joining that group, or unplug and reconnect the mouse after reloading the rule.

## Install

Choose either a user installation or a system-wide installation.

### Current user

```sh
make user-install
make install-autostart  # Optional: restore Hyprland pointer settings at login
```

Ensure `~/.local/bin` is in `PATH`, then launch **Kone Pro Settings** from the
application menu or run `konepro-gui`.

Uninstall it with:

```sh
make user-uninstall
```

### System-wide

```sh
sudo make install
```

Uninstall it with:

```sh
sudo make uninstall
```

## Command line

```sh
konepro --help
konepro -list-all
konepro -p-all 2       # 500 Hz on every profile
konepro -prf 0 -d 800 1
```

Polling values are `0=125`, `1=250`, `2=500`, and `3=1000` Hz. See
`konepro --help` for DPI, lighting, profile, debounce, and reset options.

## Safety

The GUI reads the selected profile when opened and writes only after an Apply
button is pressed. Factory reset requires a second confirmation click. The
helper validates profile headers, checksums, response lengths, and every numeric
argument before writing.

## Credits and licensing

This project is derived from
[Tobbesson/roccat-konepro-linux](https://github.com/Tobbesson/roccat-konepro-linux).
That upstream repository does not currently declare a software license. No new
license is asserted over upstream code here; resolve permission with the
upstream author before presenting this derivative as licensed open-source
software.

## AI
This project was made with the help of AI / artificial intelligence.
