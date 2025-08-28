# 🖼️ Multi-Monitor Wallpaper Changer for GNOME

[🇩🇪 Deutsch](README.de.md) | [🇬🇧 English](README.md)

Ein kleines Bash-Skript, das automatisch **verschiedene Bilder für mehrere Monitore** zu einem großen Bild kombiniert und es als **spanned Wallpaper** in GNOME setzt (unter Xorg und Wayland).
Es liest die Monitor-Auflösungen aus, passt die Bilder an und wechselt sie in regelmäßigen Intervallen.

---

## ✨ Features

- Automatische Erkennung der Monitore (Xorg via `xrandr`, Wayland via DBus)
- Kombiniert pro Monitor ein eigenes Bild → zu einem **breiten Panorama**
- Unterstützt beliebige Formate (`jpg`, `jpeg`, `png`, `webp`)
- Zufällige oder sequentielle Bildauswahl
- Konfigurierbares Intervall (Sekunden oder Minuten)
- Fallback-Ausrichtung (oben / mittig / unten), wenn Höhen nicht passen
- Lauffähig als **systemd-Userdienst** – startet automatisch mit deiner Session
- Konfigurationsdatei unter `~/.config/multiwall/multiwall.conf`

---

## 🚀 Installation

Voraussetzungen:

- Linux mit GNOME (Xorg oder Wayland)
- [`ImageMagick`](https://imagemagick.org) (für `convert`)
- `gsettings` (kommt mit GNOME)
- `xdg-user-dirs`
- optional: `jq`, `python3-gi` (für Wayland-Erkennung)

Einfacher Einzeiler (immer neueste Version):

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/install.sh | bash
```

Oder mit **Release-Tag** (empfohlen):

```bash
REF="v1.0.0" curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/install.sh | bash
```

Die Installation legt an:

- Binary: `~/.local/bin/multi-monitor-wallpaper.sh`
- Config: `~/.config/multiwall/multiwall.conf`
- Datenordner: `~/.local/share/multiwall/`
- systemd-Userdienst: `wallpaper-span.service`

Der Dienst startet sofort und aktualisiert dein Wallpaper in Intervallen.

---

## ⚙️ Konfiguration

Datei: `~/.config/multiwall/multiwall.conf`

Beispiel:

```ini
# Ordner mit Quellbildern (nutze ~ für HOME)
WALL_DIR=~/Pictures/wallpaper

# Ausgabeordner (Default ist ~/.local/share/multiwall)
OUT_DIR=~/.local/share/multiwall

# Intervall: entweder Minuten ODER Sekunden (nur eines setzen)
INTERVAL_MIN=5
# INTERVAL_SEC=0

# Zufällige Auswahl? (1 = ja, 0 = nacheinander)
SHUFFLE=1

# JPEG-Qualität (1–100)
JPEG_QUALITY=92

# Fallback-Ausrichtung: top|center|bottom
VERT_ALIGN=bottom

# Ausgabedatei-Basisname
BASENAME=background-combined
```

🔄 Änderungen an der Config werden automatisch übernommen – kein Neustart nötig.

---

## 🖥️ Systemd-Integration

Der Installer richtet einen Userdienst ein:

```bash
systemctl --user status wallpaper-span.service   # Status anzeigen
systemctl --user restart wallpaper-span.service  # Neu starten
journalctl --user -fu wallpaper-span.service     # Logs ansehen
```

---

## 🧹 Deinstallation

Binary + Dienst entfernen (Config & Daten bleiben):

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/uninstall.sh | bash
```

Vollständiges Aufräumen inkl. Config & generierten Bildern:

```bash
curl -fsSL https://raw.githubusercontent.com/nordcomputer/wallpaper-changer/main/uninstall.sh | bash -s -- --purge
```

---

## 🛠️ Entwicklung

Repo-Struktur:

```
install.sh
uninstall.sh
multi-monitor-wallpaper.sh
README.md
README.de.md
```

Änderungen am Skript können direkt getestet werden:

```bash
~/.local/bin/multi-monitor-wallpaper.sh --once
```

---

## ❤️ Credits

- [ImageMagick](https://imagemagick.org) für die Bildbearbeitung
- GNOME & [xdg-user-dirs](https://www.freedesktop.org/wiki/Software/xdg-user-dirs/) für Verzeichnis-Standards
- inspiriert durch verschiedene Snippets aus Reddit/Linux-Foren
