#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

# ----------------------------
# Helpers
# ----------------------------

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
    rm -v -- "$dst"
  else
    echo "Skip (not a Polarway symlink): $dst"
  fi
}

restore_backup_item() {
  local backup_dir="$1"
  local dst="$2"

  [[ -e "$dst" || -L "$dst" ]] && return 0

  # New backup naming scheme (HOME__config__hypr)
  local key
  key="${dst/#$HOME\//HOME\/}"
  key="${key//\//__}"
  if [[ -e "$backup_dir/$key" ]]; then
    echo "Restoring backup: $backup_dir/$key -> $dst"
    mkdir -p "$(dirname "$dst")"
    mv -v -- "$backup_dir/$key" "$dst"
    return 0
  fi

  # Old backup naming scheme (basename only, e.g. "hypr")
  local base
  base="$(basename "$dst")"
  if [[ -e "$backup_dir/$base" ]]; then
    echo "Restoring backup: $backup_dir/$base -> $dst"
    mkdir -p "$(dirname "$dst")"
    mv -v -- "$backup_dir/$base" "$dst"
    return 0
  fi

  return 0
}

restore_backups() {
  [[ -f "$BACKUP_MARKER" ]] || return 0
  local backup_dir
  backup_dir="$(cat "$BACKUP_MARKER")"
  [[ -d "$backup_dir" ]] || return 0

  # Restore config dirs if they were backed up
  restore_backup_item "$backup_dir" "$HOME/.config/hypr"
  restore_backup_item "$backup_dir" "$HOME/.config/waybar"
  restore_backup_item "$backup_dir" "$HOME/.config/mako"
  restore_backup_item "$backup_dir" "$HOME/.config/wofi"

  # Restore scripts if they were backed up
  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-wallpaper-random"
  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-power-menu"
}

# ----------------------------
# Remove Polarway symlinks
# ----------------------------

remove_link "$HOME/.config/hypr"
remove_link "$HOME/.config/waybar"
remove_link "$HOME/.config/mako"
remove_link "$HOME/.config/wofi"  # optional

remove_link "$HOME/.local/bin/polarway-wallpaper-random"
remove_link "$HOME/.local/bin/polarway-power-menu"

# ----------------------------
# Restore backups (if present)
# ----------------------------

restore_backups

echo "Note: backups are kept inside the repo under .backup/"