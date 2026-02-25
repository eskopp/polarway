#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

is_polarway_link() {
  local dst="$1"
  [[ -L "$dst" ]] || return 1
  local resolved
  resolved="$(readlink -f -- "$dst")"
  [[ "$resolved" == "$REPO_DIR/"* ]]
}

remove_link() {
  local dst="$1"
  if is_polarway_link "$dst"; then
    echo "Removing Polarway symlink: $dst"
    rm -v "$dst"
  else
    echo "Skip (not a Polarway symlink): $dst"
  fi
}

restore_backup() {
  [[ -f "$BACKUP_MARKER" ]] || return 0
  local backup_dir
  backup_dir="$(cat "$BACKUP_MARKER")"
  [[ -d "$backup_dir" ]] || return 0

  for name in hypr waybar wofi mako; do
    local dst="$HOME/.config/$name"
    local src="$backup_dir/$name"
    if [[ -e "$src" && ! -e "$dst" ]]; then
      echo "Restoring backup: $src -> $dst"
      mv -v "$src" "$dst"
    fi
  done
}

remove_link "$HOME/.config/hypr"
remove_link "$HOME/.config/waybar"
remove_link "$HOME/.config/wofi"
remove_link "$HOME/.config/mako"

restore_backup

echo "Note: backups are kept inside the repo under .backup/"