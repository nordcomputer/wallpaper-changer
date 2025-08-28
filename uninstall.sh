#!/usr/bin/env bash
set -euo pipefail
BIN="$HOME/.local/bin/multi-monitor-wallpaper.sh"
SERVICE="$HOME/.config/systemd/user/wallpaper-span.service"

systemctl --user stop wallpaper-span.service 2>/dev/null || true
systemctl --user disable wallpaper-span.service 2>/dev/null || true
systemctl --user daemon-reload

rm -f "$BIN" "$SERVICE"
echo "🧹 Entfernt: $BIN"
echo "🧹 Entfernt: $SERVICE"
echo "Hinweis: Config und generierte Bilder habe ich absichtlich NICHT gelöscht:"
echo "  • ~/.config/multiwall/"
echo "  • ~/.local/share/multiwall/"
