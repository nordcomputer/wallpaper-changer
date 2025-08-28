#!/usr/bin/env bash
set -euo pipefail

# ========================
# Einstellungen
# ========================
REPO_DEFAULT="nordcomputer/wallpaper-changer"     # <--- HIER anpassen oder beim Aufruf REPO=... setzen
REPO="${REPO:-$REPO_DEFAULT}"

# Optional: konkreten Ref/Tag/Branch vorgeben (z.B. REF=v1.0.0). Sonst: latest → main
REF="${REF:-}"

BIN_DIR="$HOME/.local/bin"
BIN_TARGET="$BIN_DIR/multi-monitor-wallpaper.sh"

CONF_DIR="$HOME/.config/multiwall"
CONF_FILE="$CONF_DIR/multiwall.conf"

DATA_DIR="$HOME/.local/share/multiwall"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/wallpaper-span.service"

# ========================
# Hilfsfunktionen
# ========================
have() { command -v "$1" >/dev/null 2>&1; }

die() { echo "❌ $*" >&2; exit 1; }

fetch() {
  # fetch <url> [outfile]
  local url="$1" out="${2:-}"
  if have curl; then
    if [[ -n "$out" ]]; then curl -fsSL "$url" -o "$out"; else curl -fsSL "$url"; fi
  elif have wget; then
    if [[ -n "$out" ]]; then wget -qO "$out" "$url"; else wget -qO- "$url"; fi
  else
    die "Weder curl noch wget verfügbar."
  fi
}

latest_release_tag() {
  # gibt Tag-Name des neuesten Releases aus oder leere Zeile
  have curl || return 0
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
   | grep -Po '"tag_name":\s*"\K.*?(?=")' || true
}

resolve_ref() {
  if [[ -n "$REF" ]]; then
    echo "$REF"
    return
  fi
  local tag
  tag="$(latest_release_tag || true)"
  if [[ -n "$tag" ]]; then
    echo "$tag"
  else
    echo "main"
  fi
}

raw_url() { echo "https://raw.githubusercontent.com/${REPO}/${1}/${2}"; }

ensure_systemd_user() {
  have systemctl || die "systemctl fehlt. systemd-Userdienste sind erforderlich."
}

xdg_pictures_dir() {
  local d
  if have xdg-user-dir; then
    d="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  fi
  [[ -n "${d:-}" ]] || d="$HOME/Pictures"
  echo "$d"
}

# ========================
# Vorprüfungen
# ========================
[[ "$REPO" != "USER/REPO" ]] || die "Bitte REPO_DEFAULT in install.sh anpassen ODER REPO=owner/repo beim Aufruf setzen."
ensure_systemd_user

REF_RESOLVED="$(resolve_ref)"
echo "📦 Quelle: ${REPO} @ ${REF_RESOLVED}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ========================
# Dateien aus Repo holen
# ========================
echo "⬇️  Lade Skripte…"
fetch "$(raw_url "$REF_RESOLVED" "multi-monitor-wallpaper.sh")" "$TMPDIR/multi-monitor-wallpaper.sh"
fetch "$(raw_url "$REF_RESOLVED" "uninstall.sh")"              "$TMPDIR/uninstall.sh"

chmod +x "$TMPDIR/multi-monitor-wallpaper.sh" "$TMPDIR/uninstall.sh"

# ========================
# Installieren
# ========================
mkdir -p "$BIN_DIR" "$DATA_DIR" "$CONF_DIR" "$SYSTEMD_USER_DIR"

install -m 0755 "$TMPDIR/multi-monitor-wallpaper.sh" "$BIN_TARGET"
install -m 0755 "$TMPDIR/uninstall.sh"               "$HOME/.local/bin/uninstall-multiwall.sh"

echo "✅ Installiert: $BIN_TARGET"
echo "✅ Installiert: $HOME/.local/bin/uninstall-multiwall.sh"
echo "✅ Datenordner: $DATA_DIR"

# ========================
# Beispiel-Config schreiben (falls nicht vorhanden)
# ========================
if [[ -f "$CONF_FILE" ]]; then
  echo "ℹ️  Config existiert bereits: $CONF_FILE (unverändert)."
else
  PICTURES_DIR="$(xdg_pictures_dir)"
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

# ========================
# systemd-Userdienst schreiben
# ========================
cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Multi-monitor Wallpaper Refresher (GNOME Wayland/Xorg)
After=graphical-session.target
Wants=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
# Session-DBus/Env für gsettings bereitstellen:
ExecStartPre=/usr/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS
ExecStart=%h/.local/bin/multi-monitor-wallpaper.sh
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

echo "✅ systemd-Userdienst geschrieben: $SERVICE_FILE"

# ========================
# Dienst aktivieren/ starten
# ========================
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-span.service

echo
echo "🎉 Installation fertig!"
echo "• Script:     $BIN_TARGET"
echo "• Config:     $CONF_FILE"
echo "• Output dir: $DATA_DIR"
echo "• Service:    wallpaper-span.service"
echo
echo "Nützlich:"
echo "  systemctl --user status wallpaper-span.service"
echo "  journalctl --user -fu wallpaper-span.service"
echo "  systemctl --user restart wallpaper-span.service"
