# Predator RGB · Omarchy

![Acer Predator Helios Neo 16 keyboard backlight](./preview.png)

[![Demo Video](https://img.youtube.com/vi/nR_2H0sh1xg/0.jpg)](https://youtube.com/shorts/nR_2H0sh1xg)

An Omarchy plugin that keeps the **Acer Predator Helios Neo 16** keyboard backlight and rear lid logo in sync with the active Omarchy theme. Every time you switch themes, the LEDs switch to the theme's **accent color** at 100% brightness.

## How it works

1. On every theme change, Omarchy writes the theme accent hex to `~/.local/state/omarchy/current/theme/keyboard.rgb`.
2. The installed `theme-set.d` hook (`theme-set`) reads that hex and drives the `acer_rgb` kernel module via sysfs.
3. A bar widget shows the current theme + accent and LED status.

## Supported LEDs

- **Keyboard**: 4-zone RGB backlight, all zones set to the theme accent.
- **Rear lid logo**: switched on/off and colored via WMI.

## Requirements

- Omarchy with the template/hook system
- Acer Predator Helios Neo 16 **PHN16-72** (kernel module DMI match)
- **Kernel headers** (`sudo pacman -S linux-headers`)

## Install

### 1. Install the plugin

```sh
omarchy plugin add git@github.com:skvggor/predator-rgb-omarchy-plugin.git --enable
```

### 2. Install the kernel module

Open the panel from the bar icon and click to copy the install command, or run
it directly:

```sh
cd ~/.config/omarchy/plugins/skvggor.predator-rgb && sudo ./bin/omarchy-install-predator-rgb --install
```

You will be asked for your password. The script compiles the module **as your
user, unprivileged**, then installs the resulting `.ko`, the udev rule and the
udev helper from copies root has verified, loads the module, adds you to the
`acer_rgb` group and restarts the shell.

Log out and back in once so the group membership takes effect. The keyboard LED
then follows the active Omarchy theme automatically.

This plugin loads a kernel module: your own C code, running in kernel space.
Read [Security](SECURITY.md) before installing. `./bin/omarchy-install-predator-rgb --check`
reports the installed module, its digest, and whether it is loaded.

## Usage

Theme changes sync automatically. The bar icon opens a panel showing the current theme, accent color, and LED status.

## Uninstall

### 1. Remove the kernel module

```sh
cd ~/.config/omarchy/plugins/skvggor.predator-rgb
sudo ./bin/omarchy-install-predator-rgb --uninstall
```

### 2. Remove the plugin

```sh
omarchy plugin remove skvggor.predator-rgb
```

## Manual commands

Run from the plugin directory (`~/.config/omarchy/plugins/skvggor.predator-rgb`):

| Command | Description |
|---------|-------------|
| `sudo ./bin/omarchy-install-predator-rgb --install` | Build unprivileged, then install and load the module |
| `sudo ./bin/omarchy-install-predator-rgb --uninstall` | Unload and remove the module, and revoke the group membership |
| `sudo ./bin/omarchy-install-predator-rgb --load` | Load the kernel module (if already installed) |
| `sudo ./bin/omarchy-install-predator-rgb --unload` | Unload the kernel module (keeps it installed) |
| `./bin/omarchy-install-predator-rgb --check` | Check if kernel headers are available |

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Omarchy plugin manifest (bar widget) |
| `Panel.qml` | Bar widget UI (status display) |
| `BarWidget.qml` | Bar icon and tooltip |
| `Service.qml` | Plugin state detection and apply logic |
| `LedIndicator.qml` | LED status indicator component |
| `Model.js` | Pure JS helpers: hex parsing |
| `theme-set` | Reads accent hex and writes to acer_rgb sysfs |
| `bin/omarchy-install-predator-rgb` | Kernel module install/uninstall script |
| `kernel-module/src/acer_rgb.c` | Kernel module: WMI control of 4-zone keyboard + back logo |
| `kernel-module/Makefile` | Compiles only; it writes no system path |
| `udev/90-acer-rgb.rules` | udev rule that sets sysfs permissions on hotplug |
| `udev/acer-rgb-set-perms` | udev helper, runs as root |
| `udev/pinned-digests.sha256` | Digests of the two udev files, checked before install |

## Development

```sh
npm test                 # Model.js, installer and version tests
bash tests/theme-set.test.sh  # theme hook integration checks
omarchy plugin validate .     # manifest schema check
```

Building the module by hand uses a random temporary build directory:

```sh
make -C kernel-module            # leaves acer_rgb.ko in a mktemp directory
make -C kernel-module BUILD_DIR=/tmp/acer-build   # or choose one yourself
```

`BUILD_DIR` must not contain spaces: the kernel build system re-invokes `make`
with `M=$(M)` unquoted, so a checkout under a path like `~/Dropbox/Linux Files/`
cannot build in place.

## License

GNU General Public License v3.0.
