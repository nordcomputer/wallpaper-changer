#!/usr/bin/env bash
set -euo pipefail

# =======================
# XDG-Pfade, Defaults, Config
# =======================

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

CONFIG_DIR="$XDG_CONFIG_HOME/multiwall"
CONFIG_FILE="$CONFIG_DIR/multiwall.conf"
OUT_DIR_DEFAULT="$XDG_DATA_HOME/multiwall"

# Default-Bilderordner (lokalisierungssicher)
if command -v xdg-user-dir >/dev/null 2>&1; then
  _PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || true)"
  [[ -n "${_PICTURES_DIR:-}" ]] || _PICTURES_DIR="$HOME/Pictures"
else
  _PICTURES_DIR="$HOME/Pictures"
fi

# --- Defaults (per Config überschreibbar) ---
WALL_DIR="$_PICTURES_DIR"
OUT_DIR="$OUT_DIR_DEFAULT"
BASENAME="background-combined"
JPEG_QUALITY=100
SHUFFLE=1
# Intervall: entweder MINUTEN ODER SEKUNDEN setzen (Config darf eines von beiden befüllen)
INTERVAL_MIN=5
INTERVAL_SEC=""

# Optionaler Align-Fallback, falls keine Y-Positionen verfügbar sind
VERT_ALIGN="bottom"

# ---- Pfad-Expansion für ~ ----
expand_path() {
  local p="${1:-}"
  [[ -z "$p" ]] && { printf '%s' ""; return 0; }
  [[ "$p" == "~"* ]] && p="${p/#\~/$HOME}"
  printf '%s' "$p"
}

# --- Config laden ---
load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local allowed='^(WALL_DIR|OUT_DIR|BASENAME|JPEG_QUALITY|SHUFFLE|VERT_ALIGN|INTERVAL_MIN|INTERVAL_SEC)='
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ $allowed ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    # Quotes außen entfernen
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    case "$key" in
      WALL_DIR|OUT_DIR|BASENAME|VERT_ALIGN) printf -v "$key" '%s' "$val" ;;
      JPEG_QUALITY|SHUFFLE|INTERVAL_MIN|INTERVAL_SEC) printf -v "$key" '%s' "${val//[^0-9]/}" ;;
    esac
  done < "$CONFIG_FILE"
}

load_config
# Pfade nach dem Laden expandieren
WALL_DIR="$(expand_path "$WALL_DIR")"
OUT_DIR="$(expand_path "$OUT_DIR")"

# Intervall in Sekunden bestimmen
if [[ -n "${INTERVAL_SEC:-}" && "${INTERVAL_SEC:-0}" -gt 0 ]]; then
  SLEEP_SEC="$INTERVAL_SEC"
else
  SLEEP_SEC="$(( INTERVAL_MIN * 60 ))"
fi

# =======================
# Argument-Parsing
# =======================
ONCE=0
for arg in "$@"; do   # <— kein ${@:-} verwenden
  case "$arg" in
    --once) ONCE=1 ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--once]

  --once   Einmal Hintergrund generieren/setzen und sofort beenden.
EOF
      exit 0
      ;;
    *)
      echo "Unbekannte Option: $arg" >&2
      exit 1
      ;;
  esac
done

# =======================
# Checks & Verzeichnisse
# =======================

command -v convert >/dev/null 2>&1 || { echo "Fehlt: ImageMagick (convert)"; exit 1; }
command -v gsettings >/dev/null 2>&1 || { echo "Fehlt: gsettings"; exit 1; }

mkdir -p "$OUT_DIR"

# A/B-Dateien für zuverlässige GNOME-Aktualisierung
TARGET_A="$OUT_DIR/${BASENAME}-A.jpg"
TARGET_B="$OUT_DIR/${BASENAME}-B.jpg"
USE_A=1

# =======================
# Monitor-Erkennung
# =======================

detect_monitors() {
  unset MON_W MON_H MON_X MON_Y MONITORS
  declare -g -a MON_W MON_H MON_X MON_Y MONITORS

  # --- Helper: xrandr-Parser (nutzen wir als Fallback, auch unter Wayland) ---
  parse_xrandr() {
    mapfile -t _rows < <(
      xrandr | awk '
        / connected/ {
          if (match($0, /([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/, a)) {
            # X Y W H
            printf "%d %d %d %d\n", a[3], a[4], a[1], a[2]
          }
        }
      ' | sort -n -k1,1 -k2,2
    )
    if ((${#_rows[@]}==0)); then
      return 1
    fi
    for r in "${_rows[@]}"; do
      read -r X Y W H <<<"$r"
      MON_X+=("$X"); MON_Y+=("$Y"); MON_W+=("$W"); MON_H+=("$H"); MONITORS+=("${W}x${H}")
    done
    return 0
  }

  # --- Helper: Layout-Validierung ---
  is_suspect_layout() {
    # Verdächtig, wenn alle Monitore exakt gleiche WxH haben ODER W/H==0 vorkommt
    local same=1
    for i in "${!MON_W[@]}"; do
      if (( MON_W[i]==0 || MON_H[i]==0 )); then
        return 0
      fi
      if (( i>0 )) && { [[ "${MON_W[i]}" -ne "${MON_W[0]}" ]] || [[ "${MON_H[i]}" -ne "${MON_H[0]}" ]]; }; then
        same=0
      fi
    done
    (( same==1 )) && return 0
    return 1
  }

  # --- 1) Wayland/DBus (Mutter) ---
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v python3 >/dev/null 2>&1; then
    local json
    json="$(python3 - <<'PY'
import json
try:
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio
except Exception:
    print(json.dumps({"error":"python3-gi missing"}))
    raise SystemExit

def is_num(x): return isinstance(x, (int, float))

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
res = bus.call_sync(
    'org.gnome.Mutter.DisplayConfig',
    '/org/gnome/Mutter/DisplayConfig',
    'org.gnome.Mutter.DisplayConfig',
    'GetCurrentState',
    None, None, Gio.DBusCallFlags.NONE, -1, None
)
state = res.unpack()
logical_monitors = state[2]

out = []
for lm in logical_monitors:
    scale = float(lm[3])
    x = int(round(float(lm[1]) * scale))
    y = int(round(float(lm[2]) * scale))

    props = lm[-1] if isinstance(lm[-1], dict) else {}
    lw = props.get('logical-width'); lh = props.get('logical-height')
    # manche Versionen nutzen evtl. underscores
    if not is_num(lw): lw = props.get('logical_width')
    if not is_num(lh): lh = props.get('logical_height')

    if is_num(lw) and is_num(lh):
        w = int(round(float(lw) * scale))
        h = int(round(float(lh) * scale))
    else:
        # Fallback über current_mode(s)
        w = 0; h = 0
        for m in lm[6]:
            modes = m[4]; cur = m[5]
            try:
                mw, mh = modes[cur][0], modes[cur][1]
                w += int(round(float(mw) * scale))
                h  = max(h, int(round(float(mh) * scale)))
            except Exception:
                pass
        if w<=0 or h<=0:
            w, h = 1920, 1080
    out.append({"x":x, "y":y, "w":w, "h":h})

out.sort(key=lambda m: (m["x"], m["y"]))
print(json.dumps(out))
PY
)"
    if [[ "$json" == *"python3-gi missing"* ]]; then
      echo "Hinweis: Bitte 'python3-gi' installieren (Wayland-Erkennung)." >&2
      # kein unmittelbarer Exit: wir versuchen xrandr
    elif command -v jq >/dev/null 2>&1; then
      local n; n="$(printf '%s' "$json" | jq 'length')" || n=0
      if (( n > 0 )); then
        for ((i=0; i<n; i++)); do
          MON_X+=("$(printf '%s' "$json" | jq -r ".[$i].x | floor")")
          MON_Y+=("$(printf '%s' "$json" | jq -r ".[$i].y | floor")")
          MON_W+=("$(printf '%s' "$json" | jq -r ".[$i].w | floor")")
          MON_H+=("$(printf '%s' "$json" | jq -r ".[$i].h | floor")")
          MONITORS+=("$(printf '%s' "$json" | jq -r ".[$i].w | floor")x$(printf '%s' "$json" | jq -r ".[$i].h | floor")")
        done
        # Prüfen, ob das plausibel ist; wenn nicht → xrandr fallback
        if is_suspect_layout && command -v xrandr >/dev/null 2>&1; then
          unset MON_W MON_H MON_X MON_Y MONITORS
          declare -g -a MON_W MON_H MON_X MON_Y MONITORS
          if parse_xrandr; then return 0; else return 0; fi
        fi
        return 0
      fi
    fi
    # Wenn wir hier landen: Wayland-Pfad hat nichts Brauchbares geliefert → später xrandr versuchen
  fi

  # --- 2) xrandr (unter Xorg UND als Fallback unter Wayland/XWayland) ---
  if command -v xrandr >/dev/null 2>&1; then
    if parse_xrandr; then
      return 0
    fi
  fi

  echo "Monitor-Erkennung fehlgeschlagen." >&2
  return 1
}


# =======================
# Bilderliste laden (robust, NUL-getrennt)
# =======================

load_images() {
  unset IMAGES
  declare -g -a IMAGES=()
  if [[ ! -d "$WALL_DIR" ]]; then
    echo "Wallpaper-Ordner existiert nicht: $WALL_DIR"
    exit 1
  fi
  while IFS= read -r -d '' f; do
    IMAGES+=("$f")
  done < <(
    { find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 2>/dev/null || true; } \
    | sort -z
  )
  if (( ${#IMAGES[@]} == 0 )); then
    echo "Keine Bilder in $WALL_DIR gefunden."
    exit 1
  fi
}

# =======================
# Bildauswahl
# =======================

INDEX=0
_SHUFFLED_DONE=""

pick_images() {
  local need=${#MONITORS[@]}
  local picks=()
  if (( ${#IMAGES[@]} < need )); then
    echo "Zu wenige Bilder (${#IMAGES[@]}) für ${#MONITORS[@]} Monitore in $WALL_DIR." >&2
    exit 1
  fi
  if (( SHUFFLE == 1 )) && [[ -z "$_SHUFFLED_DONE" ]]; then
    mapfile -d '' -t IMAGES < <(printf '%s\0' "${IMAGES[@]}" | shuf -z)
    _SHUFFLED_DONE=1
  fi
  for ((i=0; i<need; i++)); do
    picks+=( "${IMAGES[INDEX]}" )
    INDEX=$(( (INDEX + 1) % ${#IMAGES[@]} ))
  done
  printf '%s\n' "${picks[@]}"
}

# =======================
# Komposition
# =======================

compose_wall() {
  local -a picks=( "$@" )
  local -a segments=()

  local MIN_Y=999999 MAX_Y=-1
  for i in "${!MON_W[@]}"; do
    (( MON_Y[i] < MIN_Y )) && MIN_Y=${MON_Y[i]}
    local bottom=$(( MON_Y[i] + MON_H[i] ))
    (( bottom > MAX_Y )) && MAX_Y=$bottom
  done
  local HMAX=$(( MAX_Y - MIN_Y ))
  if (( HMAX <= 0 )); then
    local h0="${MON_H[0]:-1080}"
    HMAX="$h0"
  fi

  local fallback_grav="north"
  case "${VERT_ALIGN,,}" in
    bottom) fallback_grav="south" ;;
    center|middle) fallback_grav="center" ;;
    top|*) fallback_grav="north" ;;
  esac

  for i in "${!MONITORS[@]}"; do
    local img="${picks[$i]}"
    local w="${MON_W[$i]}"
    local h="${MON_H[$i]}"
    local use_fallback=0
    if [[ -z "${MON_Y[$i]:-}" || -z "${MON_H[$i]:-}" || "$HMAX" -le 0 ]]; then
      use_fallback=1
    fi
    if (( use_fallback == 0 )); then
      local topPad=$(( MON_Y[i] - MIN_Y ))
      (( topPad < 0 )) && topPad=0
      segments+=(
        "(" "$img"
          -auto-orient
          -resize "${w}x${h}^" -gravity center -extent "${w}x${h}"
          -background black -gravity north -splice "0x${topPad}"
          -background black -extent "${w}x${HMAX}"
        ")"
      )
    else
      segments+=(
        "(" "$img"
          -auto-orient
          -resize "${w}x${h}^" -gravity center -extent "${w}x${h}"
          -background black -gravity "$fallback_grav" -extent "${w}x${HMAX}"
        ")"
      )
    fi
  done

  local target="$TARGET_A"
  if (( USE_A == 1 )); then target="$TARGET_A"; USE_A=0; else target="$TARGET_B"; USE_A=1; fi

  convert "${segments[@]}" +append -interlace Line -sampling-factor 4:2:0 -quality "$JPEG_QUALITY" "$target"

  local uri="file://$target"
  gsettings set org.gnome.desktop.background picture-uri "$uri"
  gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
  gsettings set org.gnome.desktop.background picture-options 'spanned'

  echo "Wallpaper aktualisiert: $target"
}

# =======================
# Start
# =======================

# Bilder laden
load_images

# Monitore erkennen
if detect_monitors; then
  echo "Ermittelte Monitore:"
  for i in "${!MONITORS[@]}"; do
    echo "  [$i] ${MON_W[$i]}x${MON_H[$i]} @ (${MON_X[$i]},${MON_Y[$i]})"
  done
else
  echo "Falle auf statische Liste zurück."
  MONITORS=( "1920x1080" )
  MON_W=(1920); MON_H=(1080); MON_X=(0); MON_Y=(0)
fi

# Initial generieren
mapfile -t PICKS < <(pick_images)
compose_wall "${PICKS[@]}"

# Einmal-Modus?
if (( ONCE )); then
  echo "✅ Wallpaper einmal gesetzt. Beende."
  exit 0
fi

# =======================
# Loop (Config live nachladen möglich)
# =======================

PREV_WALL_DIR="$WALL_DIR"
PREV_OUT_DIR="$OUT_DIR"

while :; do
  # Config-Live-Reload
  load_config
  # Pfade expandieren nach Reload
  WALL_DIR="$(expand_path "$WALL_DIR")"
  OUT_DIR="$(expand_path "$OUT_DIR")"

  # Intervall neu setzen
  if [[ -n "${INTERVAL_SEC:-}" && "${INTERVAL_SEC:-0}" -gt 0 ]]; then
    SLEEP_SEC="$INTERVAL_SEC"
  else
    SLEEP_SEC="$(( INTERVAL_MIN * 60 ))"
  fi

  # Wenn sich OUT_DIR geändert hat → Zielpfade & Ordner aktualisieren
  if [[ "$OUT_DIR" != "$PREV_OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    TARGET_A="$OUT_DIR/${BASENAME}-A.jpg"
    TARGET_B="$OUT_DIR/${BASENAME}-B.jpg"
    PREV_OUT_DIR="$OUT_DIR"
  fi

  # Wenn sich WALL_DIR geändert hat → Bilder neu laden
  if [[ "$WALL_DIR" != "$PREV_WALL_DIR" ]]; then
    _SHUFFLED_DONE=""
    INDEX=0
    load_images
    PREV_WALL_DIR="$WALL_DIR"
  fi

  sleep "$SLEEP_SEC"

  # Bei Dock/Undock erneut erkennen
  detect_monitors || true

  mapfile -t PICKS < <(pick_images)
  compose_wall "${PICKS[@]}"
done
