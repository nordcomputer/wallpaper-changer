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

  --purge   Löscht zusätzlich Config und generierte Bilder:
            - ${CONF_DIR}
            - ${DATA_DIR}
  --quiet   Weniger Ausgabe

Ohne --purge bleiben Config & Daten erhalten.
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
    *) err "Unbekannte Option: $1"; usage; exit 1 ;;
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
    log "🧹 Entfernt: $SERVICE"
  else
    log "ℹ️  Service-Datei nicht gefunden (ok): $SERVICE"
  fi
  # Reload der User-Units
  systemctl --user daemon-reload || true
else
  warn "systemctl nicht verfügbar – überspringe Dienst-Stop/Disable."
  # Falls die Datei existiert, trotzdem löschen
  [[ -f "$SERVICE" ]] && { rm -f "$SERVICE"; log "🧹 Entfernt: $SERVICE"; }
fi

# ========================
# Binary entfernen
# ========================
if [[ -f "$BIN" ]]; then
  rm -f "$BIN"
  log "🧹 Entfernt: $BIN"
else
  log "ℹ️  Binary nicht gefunden (ok): $BIN"
fi

# Alternative Kopie (von install.sh angelegt) entfernen
if [[ -f "$SELF_ALT" ]]; then
  # nicht sich selbst löschen, falls gerade von dort gestartet
  if [[ "$(readlink -f "$0")" != "$(readlink -f "$SELF_ALT")" ]]; then
    rm -f "$SELF_ALT"
    log "🧹 Entfernt: $SELF_ALT"
  else
    # Nach dem Exit löschen
    trap 'rm -f "$SELF_ALT" >/dev/null 2>&1 || true' EXIT
    log "🧹 Entferne nach Script-Ende: $SELF_ALT"
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
    log "ℹ️  Config-Ordner nicht gefunden (ok): $CONF_DIR"
  fi
  if [[ -d "$DATA_DIR" ]]; then
    rm -rf "$DATA_DIR"
    log "🧹 Entfernt (Daten): $DATA_DIR"
  else
    log "ℹ️  Daten-Ordner nicht gefunden (ok): $DATA_DIR"
  fi
else
  log "ℹ️  Config & Daten beibehalten. Mit --purge würdest du löschen:"
  log "    - $CONF_DIR"
  log "    - $DATA_DIR"
fi

log "✅ Uninstall abgeschlossen."
