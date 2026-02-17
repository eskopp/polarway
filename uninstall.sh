#!/usr/bin/env bash
set -euo pipefail

remove_link() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    echo "Removing symlink: $dst"
    rm -v "$dst"
  else
    echo "Skip (not a symlink): $dst"
  fi
}

remove_link "$HOME/.config/hypr"
remove_link "$HOME/.config/waybar"
remove_link "$HOME/.config/rofi"
remove_link "$HOME/.config/mako"
remove_link "$HOME/.config/kitty"

echo "Note: backups are kept inside the repo under .backup/"
