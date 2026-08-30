# Predator RGB · Omarchy

![Acer Predator Helios Neo 16 keyboard backlight](./preview.png)

[![Demo Video](https://img.youtube.com/vi/nR_2H0sh1xg/0.jpg)](https://youtube.com/shorts/nR_2H0sh1xg)

An Omarchy plugin that keeps the **Acer Predator Helios Neo 16** keyboard backlight in sync with the active Omarchy theme. Every time you switch themes, the LEDs switch to the theme's **accent color** at **100% brightness** (configurable).

## How it works

Omarchy already ships `omarchy-theme-set-keyboard`, but it only covers ASUS ROG and Framework 16, not the Acer Predator. This plugin fills that gap.

1. On every theme change, Omarchy writes the theme accent hex to `~/.local/state/omarchy/current/theme/keyboard.rgb`.
2. The installed `theme-set.d` hook (`theme-set`) reads that hex and drives the `acer-gkbbl` kernel module directly:
   - static color per zone → `/dev/acer-gkbbl-static-0`
   - 100% brightness (commit byte) → `/dev/acer-gkbbl-0`
3. A bar widget shows the current theme + accent and offers an "Apply now" button.

```
omarchy theme set <theme>
      │
      ▼
~/.local/state/omarchy/current/theme/keyboard.rgb   (#819890)
      │
      ▼
theme-set hook  (hex → per-zone static payload + brightness commit)
      │
      ▼
/dev/acer-gkbbl-static-0   (1..4)   ·   /dev/acer-gkbbl-0
```

The device nodes are world-writable (`crw-rw-rw-`), so **no root is required** at theme-change time. The hook exits silently when the module isn't loaded.

## Limitations

This plugin only drives the **keyboard** backlight (4 zones via the `acer-gkbbl` WMI module).

The **rear lid logo** (the Predator emblem on the back of the display) is **not controllable** on the Predator Helios Neo 16 **PHN16-72**:

- Its RGB uses the WMI/EC path, which does **not** expose the logo (verified by reverse-engineering the ACPI tables).
- There is **no USB HID controller** for the logo on this model (no ENEK5130 / Sunrex `05af:*` / Darfon `0d62:*`), so tools like OpenRGB cannot reach it either.
- The logo is a fixed LED driven directly by the embedded controller, with no writable endpoint exposed to Linux.

Lid-logo RGB via HID/OpenRGB is only possible on newer generations (e.g. PHN16-73 and 2024+ models) that moved lighting onto USB HID controllers.

## Requirements

- Omarchy with the template/hook system
- The `acer-gkbbl` kernel module loaded (device nodes present)
- Acer Predator Helios Neo 16 (or any laptop the module supports)

## Install

```sh
omarchy plugin add git@github.com:skvggor/predator-rgb-omarchy-plugin.git --enable
```

This installs the plugin, enables the bar widget, and applies the current theme immediately. No root is required.

Alternatively, you can install manually:

```sh
git clone git@github.com:skvggor/predator-rgb-omarchy-plugin.git
cd predator-rgb-omarchy-plugin
./install.sh
```

### Keep the kernel module loaded across reboots (one-time)

The stock `acer_wmi` driver claims the same WMI GUID as `facer` and, when auto-loaded after boot, stops the keyboard RGB from working (it unbinds `facer`). To keep `facer` as the sole driver, run this **once** with your normal sudo:

```sh
sudo ./setup-kernel-module.sh
```

This writes a single reversible file, `/etc/modprobe.d/acer-predator-rgb.conf`, blacklisting `acer_wmi`, and ensures `facer` is loaded. No root is required at theme-change time.

## Usage

Theme changes sync automatically. The bar icon opens a panel with the current theme, accent swatch, and an "Apply LED color" button (also bound to middle-click on the icon).

### Settings

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `brightness` | integer | `100` | Static LED brightness (0-100) |
| `staggerDelay` | float | `0.9` | Seconds between each zone update on change, producing a left-to-right cascade (`0` = all at once) |
| `staticDevice` | string | `/dev/acer-gkbbl-static-0` | Path to the static LED device node |
| `dynamicDevice` | string | `/dev/acer-gkbbl-0` | Path to the dynamic LED device node |

Set via `omarchy bar set skvggor.predator-rgb brightness 80` or the shell settings UI.

## Files

| File | Purpose |
|------|---------|
| `theme-set` | Hook + CLI: reads accent hex and writes static color + brightness to `/dev` |
| `manifest.json` | Omarchy plugin manifest (bar widget) |
| `Panel.qml` | Bar widget UI |
| `Service.qml` | Plugin state, refresh, and apply logic |
| `Model.js` | Pure JS helpers: hex parsing, payload bytes |
| `install.sh` / `uninstall.sh` | Install / remove hook + plugin (no root required) |
| `setup-kernel-module.sh` | One-time optional root setup: blacklists `acer_wmi` so `facer` survives reboots (`--undo` reverses) |
| `tests/` | JS unit tests + shell integration tests for the payload bytes |

## Development

```sh
npm test                 # Model.js unit tests
tests/theme-set.test.sh  # integration: verifies the exact bytes written
omarchy plugin validate . # manifest schema check
```

For linting (optional, development only):

```sh
npm install -g eslint @eslint/js
eslint .
```

## Uninstall

```sh
./uninstall.sh           # removes hook + disables widget (keeps files)
./uninstall.sh --purge   # also deletes the copied plugin files
```

`uninstall.sh` is **entirely user-space (no root)**. Fully reversible: if you ran the one-time kernel setup, undo it with:

```sh
sudo ./setup-kernel-module.sh --undo   # removes the acer_wmi blacklist
```

The stock `acer_wmi` driver is then restored after the next reboot.

## License

GNU General Public License v3.0.
