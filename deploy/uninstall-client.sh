#!/usr/bin/env bash
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
DESKTOP_DIR="$HOME/Desktop"
if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP)"
fi

echo "Remove Volley Ace application files and shortcuts? User data will be preserved."
read -r -p "Continue? [y/N] " response
if [[ ! "$response" =~ ^[Yy] ]]; then
  echo "Uninstall cancelled."
  exit 0
fi

for target in "$HOME/.local/share/volleyace" "$HOME/.local/opt/volleyace"; do
  if [[ -d "$target" ]]; then
    echo "Removing installed files from $target"
    rm -rf -- "$target"
  fi
done

for app_id in com.example.volley_ace be.heister.volleyace volleyace; do
  rm -f -- "$APPS_DIR/$app_id.desktop" "$DESKTOP_DIR/$app_id.desktop"
done
rm -f -- "$ICON_DIR/com.example.volley_ace.png"
update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

echo "Uninstall finished. User data and installation backups have been preserved."
