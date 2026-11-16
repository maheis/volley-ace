#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT
export HOME="$temporary_dir/home with spaces"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
bundle="$temporary_dir/bundle with spaces"
target="$HOME/.local/share/volleyace"
app_id="com.example.volley_ace"
mkdir -p "$HOME" "$bundle/lib" "$bundle/data/flutter_assets/assets/icons" "$XDG_CONFIG_HOME"
printf 'XDG_DESKTOP_DIR="$HOME/Desktop"\n' > "$XDG_CONFIG_HOME/user-dirs.dirs"
printf '#!/usr/bin/env bash\nprintf "<%%s>\\n" "$@"\n' > "$bundle/volley_ace"
chmod +x "$bundle/volley_ace"
printf 'test icon\n' > "$bundle/data/flutter_assets/assets/icons/color_transparent_icon.png"

printf 'y\nn\n' | bash "$project_dir/deploy/install-client.sh" "$bundle"
[[ -x "$target/volley_ace" ]]
[[ -f "$HOME/.local/share/icons/hicolor/128x128/apps/$app_id.png" ]]
desktop_file="$HOME/.local/share/applications/$app_id.desktop"
[[ -f "$desktop_file" ]]
[[ ! -e "$HOME/.local/share/icons/hicolor/128x128/apps/simple_present.png" ]]
actual="$("$target/launch-volleyace.sh" 'one file.vace' 'two.vace')"
[[ "$actual" == $'<one file.vace>\n<two.vace>' ]]
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_file"
fi

if bash "$project_dir/deploy/install-client.sh" "$temporary_dir/missing"; then
  echo 'Invalid bundles must be rejected.' >&2
  exit 1
fi
[[ -x "$target/volley_ace" ]]

printf 'n\n' | bash "$project_dir/deploy/install-client.sh" "$bundle"
[[ -x "$target/volley_ace" ]]
mkdir -p "$HOME/Documents"
printf 'preserve data\n' > "$HOME/Documents/volley_ace.db"
printf 'obsolete\n' > "$target/obsolete.txt"
printf 'legacy\n' > "$HOME/.local/share/applications/be.heister.volleyace.desktop"
printf 'y\ny\ny\n' | bash "$project_dir/deploy/install-client.sh" "$bundle"
[[ ! -e "$target/obsolete.txt" ]]
[[ -f "$HOME/Documents/volley_ace.db" ]]
[[ ! -e "$HOME/.local/share/applications/be.heister.volleyace.desktop" ]]
[[ -f "$HOME/Desktop/$app_id.desktop" ]]
backups=("$target".bak.*)
[[ -f "${backups[0]}/obsolete.txt" ]]

cp "$project_dir/deploy/install-client.sh" "$bundle/install-client.sh"
printf 'y\ny\nn\n' | bash "$bundle/install-client.sh"
[[ -x "$target/volley_ace" ]]
all_backups=("$target".bak.*)
[[ "${#all_backups[@]}" -eq 2 ]]
for backup in "${all_backups[@]}"; do
  [[ -x "$backup/volley_ace" ]]
done

bash "$project_dir/deploy/install-linux-desktop.sh" "$bundle"
[[ -x "$HOME/.local/opt/volleyace/volley_ace" ]]
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_file"
fi

printf 'other app\n' > "$HOME/.local/share/icons/hicolor/128x128/apps/simple_present.png"
printf 'n\n' | bash "$project_dir/deploy/uninstall-client.sh"
[[ -x "$target/volley_ace" ]]
printf 'y\n' | bash "$project_dir/deploy/uninstall-client.sh"
[[ ! -e "$target" ]]
[[ ! -e "$HOME/.local/opt/volleyace" ]]
[[ ! -e "$desktop_file" ]]
[[ ! -e "$HOME/Desktop/$app_id.desktop" ]]
[[ ! -e "$HOME/.local/share/icons/hicolor/128x128/apps/$app_id.png" ]]
[[ -f "$HOME/.local/share/icons/hicolor/128x128/apps/simple_present.png" ]]
[[ -f "$HOME/Documents/volley_ace.db" ]]
[[ -f "${backups[0]}/obsolete.txt" ]]
printf 'Linux installer tests passed.\n'