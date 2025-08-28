#!/usr/bin/env bash
set -euo pipefail

# ========================
# Pfade (wie in install.sh)
# ========================
BIN="$HOME/.local/bin/multi-monitor-wallpaper.sh"
SELF_ALT="$HOME/.local/bin/uninstall-multiwall.sh"   # von install.sh dorthin kopiert
SERVICE="$HOME/.config/systemd/user/wallpaper-span.service"

CONF_DIR="$HOME/.config/multiwall"
CONF_FILE="$CONF_DIR/multiwall.conf"
DATA_DIR="$HOME/.local/share/multiwall"

# ========================
# Optionen
# ========================
PURGE=0
QUIET=0

usage() {
  cat <<EOF
Uninstall Multiwall (User-Installation)

Usage: $(basename "$0") [--purge] [--quiet]

  --purge   deletes config and generated images:
            - ${CONF_DIR}
            - ${DATA_DIR}
  --quiet   less output

Without --purge Config and data will be kept.
EOF
}

log()  { (( QUIET )) || echo -e "$*"; }
warn() { (( QUIET )) || echo -e "⚠️  $*" >&2; }
err()  { echo -e "❌ $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# ========================
# Dienst stoppen/entfernen
# ========================
if have systemctl; then
  # Stoppen (ohne Fehler, falls nicht aktiv)
  systemctl --user stop wallpaper-span.service 2>/dev/null || true
  # Deaktivieren (ohne Fehler, falls nicht aktiviert)
  systemctl --user disable wallpaper-span.service 2>/dev/null || true
  # Unit-Datei entfernen
  if [[ -f "$SERVICE" ]]; then
    rm -f "$SERVICE"
    log "🧹 Removed: $SERVICE"
  else
    log "ℹ️  Service file not found (ok): $SERVICE"
  fi
  # Reload der User-Units
  systemctl --user daemon-reload || true
else
  warn "systemctl not available – skipping service Stop/Disable."
  # Falls die Datei existiert, trotzdem löschen
  [[ -f "$SERVICE" ]] && { rm -f "$SERVICE"; log "🧹 Removed: $SERVICE"; }
fi

# ========================
# Binary entfernen
# ========================
if [[ -f "$BIN" ]]; then
  rm -f "$BIN"
  log "🧹 Removed: $BIN"
else
  log "ℹ️  Binary not found (ok): $BIN"
fi

# Alternative Kopie (von install.sh angelegt) entfernen
if [[ -f "$SELF_ALT" ]]; then
  # nicht sich selbst löschen, falls gerade von dort gestartet
  if [[ "$(readlink -f "$0")" != "$(readlink -f "$SELF_ALT")" ]]; then
    rm -f "$SELF_ALT"
    log "🧹 Removed: $SELF_ALT"
  else
    # Nach dem Exit löschen
    trap 'rm -f "$SELF_ALT" >/dev/null 2>&1 || true' EXIT
    log "🧹 Removing script after ending: $SELF_ALT"
  fi
fi

# ========================
# Optional: Config & Daten
# ========================
if (( PURGE )); then
  if [[ -d "$CONF_DIR" ]]; then
    rm -rf "$CONF_DIR"
    log "🧹 Entfernt (Config): $CONF_DIR"
  else
    log "ℹ️  Config directory not found (ok): $CONF_DIR"
  fi
  if [[ -d "$DATA_DIR" ]]; then
    rm -rf "$DATA_DIR"
    log "🧹 Removed (Data): $DATA_DIR"
  else
    log "ℹ️  Data directory not found (ok): $DATA_DIR"
  fi
else
  log "ℹ️  Config and data remain in place. With --purge you would delete them:"
  log "    - $CONF_DIR"
  log "    - $DATA_DIR"
fi

log "✅ Uninstall finished."
