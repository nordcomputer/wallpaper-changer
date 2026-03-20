# 🖼️ Multi-Monitor Wallpaper Changer for GNOME

[🇩🇪 Deutsch](README.de.md) | [🇬🇧 English](README.md)

A small Bash script that automatically combines **different images for multiple monitors** into one large picture and sets it as a **spanned wallpaper** in GNOME (works on both Xorg and Wayland).
It detects monitor resolutions, adjusts the images accordingly, and changes them at regular intervals.

---

## ✨ Features

- Automatic monitor detection (Xorg via `xrandr`, Wayland via DBus)
- Combines one image per monitor → into a **wide panorama**
- Supports common formats (`jpg`, `jpeg`, `png`, `webp`)
- Randomized or sequential image selection
- Configurable interval (seconds or minutes)
- Fallback vertical alignment (top / center / bottom) if heights don’t match
- Runs as a **systemd user service** – starts automatically with your GNOME session
- Configuration file located at `~/.config/multiwall/multiwall.conf`

---

## 🚀 Installation

Requirements:

- Linux with GNOME (Xorg or Wayland)
- [`ImageMagick`](https://imagemagick.org) (for `convert`)
- `gsettings` (comes with GNOME)
- `xdg-user-dirs`
- optional: `jq`, `python3-gi` (for Wayland detection)

Quick install (always latest version):

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/install.sh | bash
```

Or install a **specific release tag** (recommended):

```bash
REF="v1.0.0" curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/install.sh | bash
```

The installer sets up:

- Binary: `~/.local/bin/multi-monitor-wallpaper.sh`
- Config: `~/.config/multiwall/multiwall.conf`
- Data folder: `~/.local/share/multiwall/`
- systemd user service: `wallpaper-span.service`

The service starts immediately and refreshes your wallpaper at the chosen interval.

---

## ⚙️ Configuration

File: `~/.config/multiwall/multiwall.conf`

Example:

```ini
# Source images folder (use ~ for HOME)
WALL_DIR=~/Pictures/wallpaper

# Output folder (default: ~/.local/share/multiwall)
OUT_DIR=~/.local/share/multiwall

# Interval: set either minutes OR seconds (only one)
INTERVAL_MIN=5
# INTERVAL_SEC=0

# Delay before first start after boot
DELAY_SECONDS=5

# Randomize selection? (1 = yes, 0 = sequential)
SHUFFLE=1

# JPEG quality (1–100)
JPEG_QUALITY=92

# Vertical fallback alignment: top|center|bottom
VERT_ALIGN=bottom

# Output filename base
BASENAME=background-combined
```

🔄 Config changes are applied automatically – no restart needed.

---

## 🖥️ Systemd Integration

The installer creates a user service:

```bash
systemctl --user status wallpaper-span.service   # show status
systemctl --user restart wallpaper-span.service  # restart service
journalctl --user -fu wallpaper-span.service     # view logs
```

---

## 🧹 Uninstallation

Remove binary and service (config & data remain):

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/uninstall.sh | bash
```

Full cleanup including config & generated images:

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/uninstall.sh | bash -s -- --purge
```

---

## 🛠️ Development

Repo structure:

```
install.sh
uninstall.sh
multi-monitor-wallpaper.sh
README.md
README.de.md
```

Test script directly:

```bash
~/.local/bin/multi-monitor-wallpaper.sh --once
```

---

## ❤️ Credits

- [ImageMagick](https://imagemagick.org) for image processing
- GNOME & [xdg-user-dirs](https://www.freedesktop.org/wiki/Software/xdg-user-dirs/) for XDG directory standards
- Inspired by various snippets from Reddit/Linux forums
