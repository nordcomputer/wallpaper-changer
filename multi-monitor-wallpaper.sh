#!/usr/bin/env bash
set -euo pipefail

# =======================
# Konfiguration
# =======================

# Ordner mit deinen Bildern (jpg/png/webp…)
WALL_DIR="$HOME/Bilder/wallpaper"

# Monitor-Auflösungen in Anzeigereihenfolge (links -> rechts).
# Beispiel: Zwei 2560x1440 Monitore + ein 1920x1080 rechts
MONITORS=( "1920x1080" "2560x1440" "2560x1440")

# Wechselintervall in Minuten
INTERVAL_MIN=1

# Zufällige Reihenfolge? (1 = ja, 0 = nacheinander)
SHUFFLE=1

# Ausgabe-Ordner & Basename
OUT_DIR="$HOME/Bilder"
BASENAME="background-combined"

# Bildqualität (JPEG) 1-100
JPEG_QUALITY=92

VERT_ALIGN="bottom"

# =======================
# Ende Konfiguration
# =======================

command -v convert >/dev/null 2>&1 || { echo "Fehlt: ImageMagick (convert)"; exit 1; }
command -v gsettings >/dev/null 2>&1 || { echo "Fehlt: gsettings"; exit 1; }

mkdir -p "$OUT_DIR"

# Wir toggeln zwischen zwei Dateinamen, damit GNOME die Änderung sicher erkennt
TARGET_A="$OUT_DIR/${BASENAME}-A.jpg"
TARGET_B="$OUT_DIR/${BASENAME}-B.jpg"
USE_A=1

# Bildliste laden
mapfile -t IMAGES < <(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
if (( ${#IMAGES[@]} == 0 )); then
  echo "Keine Bilder in $WALL_DIR gefunden."
  exit 1
fi

INDEX=0

pick_images() {
  local need=${#MONITORS[@]}
  local picks=()

  if (( SHUFFLE == 1 )); then
    # Zufällig: für Performance nur einmal mischen, wenn INDEX 0 ist
    if [[ -z "${_SHUFFLED_DONE:-}" ]]; then
      mapfile -t IMAGES < <(printf "%s\n" "${IMAGES[@]}" | shuf)
      _SHUFFLED_DONE=1
    fi
  fi

  for ((i=0; i<need; i++)); do
    picks+=( "${IMAGES[INDEX]}" )
    INDEX=$(( (INDEX + 1) % ${#IMAGES[@]} ))
  done

  printf "%s\n" "${picks[@]}"
}

compose_wall() {
  local -a picks=( "$@" )
  local -a segments=()

  # maximale Höhe aller Monitore bestimmen
  local HMAX=0
  for s in "${MONITORS[@]}"; do
    local h="${s##*x}"
    (( h > HMAX )) && HMAX="$h"
  done

  # IM gravity aus VERT_ALIGN ableiten
  local GRAV="south"
  case "$VERT_ALIGN" in
    top)    GRAV="north" ;;
    center) GRAV="center" ;;
    bottom) GRAV="south" ;;
  esac

  # Für jeden Monitor: erst auf seine exakte Größe bringen, dann auf HMAX „extenden“ und vertikal ausrichten
  for i in "${!MONITORS[@]}"; do
    local size="${MONITORS[$i]}"          # z.B. 1920x1080
    local img="${picks[$i]}"
    local w="${size%x*}"
    local h="${size#*x}"

    segments+=(
      "(" "$img"
        -auto-orient
        -resize "${size}^" -gravity center -extent "$size"   # passgenau ohne Verzerren
        -background black -gravity "$GRAV" -extent "${w}x${HMAX}"  # auf HMAX auffüllen & ausrichten
      ")"
    )
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

# Initial einmal setzen
mapfile -t PICKS < <(pick_images)
compose_wall "${PICKS[@]}"

# Loop
while :; do
  sleep "$((INTERVAL_MIN * 60))"   # statt *10
  mapfile -t PICKS < <(pick_images)
  compose_wall "${PICKS[@]}"
done
