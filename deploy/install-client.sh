#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SRC_DIR="$SCRIPT_DIR"
if [[ ! -x "$DEFAULT_SRC_DIR/volley_ace" ]]; then
  DEFAULT_SRC_DIR="$SCRIPT_DIR/../build/linux/x64/release/bundle"
fi
SRC_DIR="${1:-$DEFAULT_SRC_DIR}"
TARGET_DIR="$HOME/.local/share/volleyace"

echo "Source: $SRC_DIR"
echo "Target: $TARGET_DIR"

if [[ ! -x "$SRC_DIR/volley_ace" || ! -d "$SRC_DIR/lib" || ! -d "$SRC_DIR/data" ]]; then
  echo "Linux bundle not found or incomplete: $SRC_DIR" >&2
  echo "Build it with: flutter build linux --release" >&2
  exit 1
fi
if ! command -v rsync >/dev/null 2>&1; then
  echo "Required command not found: rsync" >&2
  exit 1
fi
SRC_DIR="$(cd "$SRC_DIR" && pwd -P)"
if [[ "$SRC_DIR" == "$TARGET_DIR" || "$SRC_DIR" == "$TARGET_DIR/"* ]]; then
  echo "Source must not be inside the installation directory." >&2
  exit 1
fi

if [ -d "$TARGET_DIR" ]; then
  read -r -p "Existing installation at $TARGET_DIR found. Update (remove and install)? [y/N] " resp
  if [[ "$resp" =~ ^[Yy] ]]; then
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    backup="$(mktemp -d "${TARGET_DIR}.bak.${ts}.XXXXXX")"
    echo "Backing up existing installation to $backup"
    mv -T -- "$TARGET_DIR" "$backup"
  else
    echo "Aborting installation."; exit 0
  fi
fi

echo "Creating target directory..."
mkdir -p "$TARGET_DIR"

echo "Copying files (excluding .git)..."
rsync -a --delete --exclude='.git' --exclude='build' "$SRC_DIR/" "$TARGET_DIR/"

echo "Creating launcher script..."
LAUNCHER="$TARGET_DIR/launch-volleyace.sh"
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\ncd -- %q\n' "$TARGET_DIR"
  printf 'exec ./volley_ace "$@"\n'
} > "$LAUNCHER"
chmod 0755 "$LAUNCHER"

read -r -p "Create start-menu entry? [Y/n] " resp
resp="${resp:-Y}"
case "$resp" in
  [Yy]* ) CREATE_MENU=1 ;;
  * ) CREATE_MENU=0 ;;
esac

read -r -p "Create desktop icon? [y/N] " resp2
resp2="${resp2:-n}"
case "$resp2" in
  [Yy]* ) CREATE_DESKTOP=1 ;;
  * ) CREATE_DESKTOP=0 ;;
esac

# Install icon into user icon theme if an asset exists
ICON_SRC=""
for candidate in "$TARGET_DIR/data/flutter_assets/assets/icons/color_transparent_icon.png" "$TARGET_DIR/assets/icons/color_transparent_icon.png" "$TARGET_DIR/color_transparent_icon.png"; do
  if [ -f "$candidate" ]; then
    ICON_SRC="$candidate"
    break
  fi
done

ICON_NAME="com.example.volley_ace"
if [ -n "$ICON_SRC" ]; then
  ICON_DEST_DIR_128="$HOME/.local/share/icons/hicolor/128x128/apps"
  ICON_DEST_DIR_SCALABLE="$HOME/.local/share/icons/hicolor/scalable/apps"
  mkdir -p "$ICON_DEST_DIR_128" "$ICON_DEST_DIR_SCALABLE"
  ICON_DEST_PNG="$ICON_DEST_DIR_128/${ICON_NAME}.png"
  cp "$ICON_SRC" "$ICON_DEST_PNG"
  chmod 0644 "$ICON_DEST_PNG"
  echo "Installed icon(s) to $ICON_DEST_DIR_128 and $ICON_DEST_DIR_SCALABLE"
  # Prefer theme icon name for .desktop entries
  DESKTOP_ICON_VALUE="$ICON_NAME"
else
  DESKTOP_ICON_VALUE=""
fi

APP_ID="com.example.volley_ace"
DESKTOP_ENTRY_NAME="$APP_ID.desktop"
DESKTOP_CONTENT="[Desktop Entry]\nName=Volley Ace\nComment=Volleyball Assistenz-App\nExec=\"$LAUNCHER\" %U\nPath=$TARGET_DIR\nIcon=$DESKTOP_ICON_VALUE\nTerminal=false\nType=Application\nCategories=Game;SportsGame;\nStartupNotify=true\nStartupWMClass=$APP_ID"

if [ "$CREATE_MENU" -eq 1 ]; then
  APPS_DIR="$HOME/.local/share/applications"
  mkdir -p "$APPS_DIR"
  # Remove legacy desktop filename to avoid duplicate launcher entries.
  rm -f "$APPS_DIR/volleyace.desktop"
  rm -f "$APPS_DIR/be.heister.volleyace.desktop"
  printf "%b" "$DESKTOP_CONTENT" > "$APPS_DIR/$DESKTOP_ENTRY_NAME"
  chmod 0644 "$APPS_DIR/$DESKTOP_ENTRY_NAME"
  echo "Installed menu entry: $APPS_DIR/$DESKTOP_ENTRY_NAME"
fi

if [ "$CREATE_DESKTOP" -eq 1 ]; then
  DESKTOP_DIR="$HOME/Desktop"
  if command -v xdg-user-dir >/dev/null 2>&1; then
    DESKTOP_DIR="$(xdg-user-dir DESKTOP)"
  fi
  mkdir -p "$DESKTOP_DIR"
  rm -f "$DESKTOP_DIR/volleyace.desktop" "$DESKTOP_DIR/be.heister.volleyace.desktop"
  printf "%b" "$DESKTOP_CONTENT" > "$DESKTOP_DIR/$DESKTOP_ENTRY_NAME"
  chmod 0644 "$DESKTOP_DIR/$DESKTOP_ENTRY_NAME"
  echo "Installed desktop icon: $DESKTOP_DIR/$DESKTOP_ENTRY_NAME"
fi

echo "Install complete. Launch with: $LAUNCHER"
echo "If you installed the menu entry, you can search for 'Volley Ace' in your application launcher."

exit 0
