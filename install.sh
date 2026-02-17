#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$REPO_DIR/.backup/$(date +%Y-%m-%d_%H-%M-%S)"

link_one() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv -v "$dst" "$BACKUP_DIR/"
  fi

  ln -sfnv "$src" "$dst"
}

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# Hyprland
if [[ -d "$REPO_DIR/configs/hypr" ]]; then
  link_one "$REPO_DIR/configs/hypr" "$HOME/.config/hypr"
fi

# Waybar
if [[ -d "$REPO_DIR/configs/waybar" ]]; then
  link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
fi

# Rofi
if [[ -d "$REPO_DIR/configs/rofi" ]]; then
  link_one "$REPO_DIR/configs/rofi" "$HOME/.config/rofi"
fi

# Mako
if [[ -d "$REPO_DIR/configs/mako" ]]; then
  link_one "$REPO_DIR/configs/mako" "$HOME/.config/mako"
fi

# Kitty
if [[ -d "$REPO_DIR/configs/kitty" ]]; then
  link_one "$REPO_DIR/configs/kitty" "$HOME/.config/kitty"
fi

# Helper scripts
if [[ -d "$REPO_DIR/configs/scripts" ]]; then
  mkdir -p "$HOME/.local/bin"
  for f in "$REPO_DIR"/configs/scripts/*; do
    [[ -f "$f" ]] || continue
    link_one "$f" "$HOME/.local/bin/$(basename "$f")"
  done
fi

echo
echo "Done."
echo "Tip: restart Waybar with: pkill waybar; waybar &"
echo "Tip: reload Hyprland with: hyprctl reload"
