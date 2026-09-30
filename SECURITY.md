# Security Policy

## What this plugin does, and what that costs you

This plugin loads a **kernel module**. The module is C code that runs in kernel
space, with the same privilege as the kernel itself. Installing this plugin is
an explicit decision to build and load your own code into the kernel, and no
installer can make that decision safe on your behalf. Read this section before
installing, and treat the checkout as privileged content.

Concretely, the highest-privilege thing this repository ships is
`kernel-module/src/acer_rgb.c`, and `bin/omarchy-install-predator-rgb --install`
compiles it and calls `modprobe` with it. Everything below describes what the
installer does around that, not a claim that the module is harmless.

## The module itself

`kernel-module/src/acer_rgb.c` matches a single DMI product
(`Acer Predator PHN16-72`) and a single WMI GUID, and refuses to initialise on
anything else, so it cannot drive LEDs on other hardware.

The two sysfs attributes it exposes are group-writable by the `acer_rgb` group
so the theme hook can run without root. That makes their write handlers a
kernel boundary, so they validate everything:

- `parse_hex_color` requires exactly six characters and parses them with
  `kstrtoint`, so no field is ever read past the end of the buffer.
- `apply_zone` rejects any zone outside `1..PREDATOR_MAX_ZONES` before indexing
  `acer_rgb_zones`, so the zone mask shift is always `1 << 0..3`.
- Both `store` handlers take a single `kstrdup`, walk the copy with `strchr`,
  and `kfree` on every error path.
- `theme-set` additionally validates `^[0-9A-Fa-f]{6}$` before writing, and
  reads the theme file with `sed` rather than sourcing it, so a crafted
  `keyboard.rgb` cannot inject a command.

Write access to these two attributes therefore lets a caller set LED colours
and brightness. It is not a path to arbitrary kernel memory.

## What the installer protects

- **The build is not privileged.** `kernel-module/Makefile` only compiles. It
  has no target that writes to `/lib/modules`, `/etc` or `/usr`, so running it
  as root would be pointless even by accident. The module is built as your
  user, and root only ever copies the finished `.ko`.
- **The build directory is unpredictable.** It comes from `mktemp -d`, not from
  a fixed path. A previous version built as root into a hardcoded
  `/tmp/acer_rgb-build`, which any local user could pre-create as a symlink and
  have root write through.
- **Root installs only from a private copy.** Copy, digest check and install run
  in one root process. The copy lands in a fresh `0700` root-owned directory
  under `/run`, so it cannot be replaced after it is verified, and the digest of
  the installed file is re-read as a check on the destination. The installed
  file itself is root-owned inside `/lib/modules`.
- **The udev files are digest-pinned.** `udev/90-acer-rgb.rules` and
  `udev/acer-rgb-set-perms` do not depend on the kernel version, so their
  SHA-256 lives in version control and is checked before they are installed.
  The helper runs as root on every hotplug, so this is the one artifact where a
  version-controlled pin is possible and it is enforced.

## What the installer does not protect

**The `.ko` has no signature and no published digest.** This is deliberate, not
an oversight. The kernel checks `vermagic` and refuses a module built for a
different kernel, so a single released `.ko` would only load on the one kernel
it was built against. On Arch that string changes with every kernel update, so a
pinned module would be unusable within days. Building at install time is the
only workable option, and it means the bytes that enter the kernel are the ones
in your checkout.

The practical consequence: a process running as you can modify the module
source, and `--install` will build and load the modified result. It cannot get
you root *through the installer*, because you are already the one who runs
`sudo`; but it can change what your own plugin loads. If that matters to you,
check `git status` and the diff of `kernel-module/src/acer_rgb.c` before
installing, and re-check after any `git pull`.

Do not run `--install` from a checkout you do not trust, and do not run it as
root from a directory another user can write to.

## Group membership

`--install` adds you to the `acer_rgb` group so the theme hook can write the
sysfs attributes without root. That membership reaches new sessions, so log out
and back in. `--uninstall` revokes it again and removes the group when it
becomes empty.

## Reporting a vulnerability

Report security issues privately through GitHub's "Report a vulnerability"
button on the Security tab of
<https://github.com/skvggor/predator-rgb-omarchy-plugin>.

Include the affected version, the steps to reproduce, and the impact. The
kernel module and the install script are the interesting surface; the QML and
`Model.js` are not.

## Out of scope

- The fact that the plugin drives keyboard LEDs through WMI at all.
- LED control on hardware other than the PHN16-72, which the module refuses.
- Colour values the WMI firmware accepts. The plugin validates the shape of
  what it writes, not the firmware's response to it.
- Vulnerabilities in the kernel, WMI or ACPI subsystem.
