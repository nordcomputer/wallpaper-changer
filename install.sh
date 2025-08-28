#!/usr/bin/env bash
set -euo pipefail

# -------- config --------
SRC_SCRIPT="${1:-./multi-monitor-wallpaper.sh}"
BIN_DIR="$HOME/.local/bin"
BIN_TARGET="$BIN_DIR/multi-monitor-wallpaper.sh"

CONF_DIR="$HOME/.config/multiwall"
CONF_FILE="$CONF_DIR/multiwall.conf"

DATA_DIR="$HOME/.local/share/multiwall"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/wallpaper-span.service"

# -------- checks --------
if [[ ! -r "$SRC_SCRIPT" ]]; then
  echo "❌ Script nicht gefunden/lesbar: $SRC_SCRIPT"
  echo "   Übergib den Pfad als 1. Argument oder lege die Datei ins aktuelle Verzeichnis."
  exit 1
fi

command -v systemctl >/dev/null 2>&1 || {
  echo "❌ systemctl nicht gefunden. systemd-Userdienste sind erforderlich."
  exit 1
}

# Optional, aber empfohlen
if ! command -v xdg-user-dir >/dev/null 2>&1; then
  echo "⚠️  'xdg-user-dir' nicht gefunden. Default-Bilderordner kann nicht automatisch ermittelt werden."
  echo "   (Auf Debian: sudo apt install xdg-user-dirs)"
fi

# -------- install binary --------
mkdir -p "$BIN_DIR"
install -m 0755 "$SRC_SCRIPT" "$BIN_TARGET"
echo "✅ Installiert: $BIN_TARGET"

# -------- create data dir --------
mkdir -p "$DATA_DIR"
echo "✅ Ordner für generierte Hintergründe: $DATA_DIR"

# -------- config file (create if missing) --------
mkdir -p "$CONF_DIR"

if [[ -f "$CONF_FILE" ]]; then
  echo "ℹ️  Config existiert bereits: $CONF_FILE (unverändert gelassen)"
else
  # Determine default Pictures dir (de, en, custom)
  PICTURES_DIR="${HOME}/Pictures"
  if command -v xdg-user-dir >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    [[ -n "$PICTURES_DIR" ]] || PICTURES_DIR="${HOME}/Pictures"
  fi

  cat > "$CONF_FILE" <<EOF
# ~/.config/multiwall/multiwall.conf

# Ordner mit den Quellbildern (nutze ~ für HOME)
WALL_DIR="${PICTURES_DIR}/wallpaper"

# Ausgabeordner (Standard ist ~/.local/share/multiwall)
OUT_DIR="~/.local/share/multiwall"

# Intervall: entweder Minuten ODER Sekunden (nur EINES setzen)
INTERVAL_MIN=5
# INTERVAL_SEC=0

# Zufällige Auswahl? 1=yes, 0=no
SHUFFLE=1

# JPEG-Qualität (1-100)
JPEG_QUALITY=92

# Vertikale Fallback-Ausrichtung: top|center|bottom
VERT_ALIGN="bottom"

# Ausgabedatei-Basisname
BASENAME="background-combined"
EOF
  echo "✅ Beispiel-Config erstellt: $CONF_FILE"
fi

# -------- systemd user service --------
mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Multi-monitor Wallpaper Refresher (GNOME Wayland/Xorg)
After=graphical-session.target
Wants=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
# Damit gsettings/DBus die laufende Session findet:
ExecStartPre=/usr/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS
ExecStart=%h/.local/bin/multi-monitor-wallpaper.sh
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

echo "✅ systemd-Userdienst geschrieben: $SERVICE_FILE"

# -------- enable + start --------
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-span.service

echo "✅ Dienst aktiviert & gestartet."

# -------- summary --------
echo
echo "🎉 Fertig!"
echo "• Binary:    $BIN_TARGET"
echo "• Config:    $CONF_FILE"
echo "• Outputdir: $DATA_DIR"
echo "• Service:   wallpaper-span.service (User)"
echo
echo "Nützliche Befehle:"
echo "  systemctl --user status wallpaper-span.service"
echo "  journalctl --user -fu wallpaper-span.service"
echo "  systemctl --user restart wallpaper-span.service"
