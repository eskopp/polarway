#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$REPO_DIR/.backup/$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

link_one() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv -v -T "$dst" "$BACKUP_DIR/$(basename "$dst")"
  fi

  ln -sfnv "$src" "$dst"
}

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# Hyprland
[[ -d "$REPO_DIR/configs/hypr"   ]] && link_one "$REPO_DIR/configs/hypr"   "$HOME/.config/hypr"
[[ -d "$REPO_DIR/configs/waybar" ]] && link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
[[ -d "$REPO_DIR/configs/wofi"   ]] && link_one "$REPO_DIR/configs/wofi"   "$HOME/.config/rofi"
[[ -d "$REPO_DIR/configs/mako"   ]] && link_one "$REPO_DIR/configs/mako"   "$HOME/.config/mako"
[[ -d "$REPO_DIR/configs/kitty"  ]] && link_one "$REPO_DIR/configs/kitty"  "$HOME/.config/kitty"

# Helper scripts
if [[ -d "$REPO_DIR/configs/scripts" ]]; then
  mkdir -p "$HOME/.local/bin"
  for f in "$REPO_DIR"/configs/scripts/*; do
    [[ -f "$f" ]] || continue
    link_one "$f" "$HOME/.local/bin/$(basename "$f")"
  done
fi

printf '%s\n' "$BACKUP_DIR" > "$BACKUP_MARKER"

echo
echo "Done."
echo "Tip: restart Waybar with: pkill waybar; waybar &"
echo "Tip: reload Hyprland with: hyprctl reload"
