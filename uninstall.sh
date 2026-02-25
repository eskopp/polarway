#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Polarway Uninstall Script (safe + conservative)
#
# What this script does:
#   1) Removes Polarway marker blocks from repo-managed config files.
#   2) Removes only Polarway-managed symlinks from $HOME (symlinks into this repo).
#   3) Restores backups created by install.sh (if present).
#
# Safety:
#   - Does NOT delete normal files/dirs that are not symlinks into this repo.
#   - Restores backups only if the destination does not exist anymore.
# -----------------------------------------------------------------------------

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

# -----------------------------------------------------------------------------
# Helpers: symlink detection / removal
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Helpers: remove marker blocks
# -----------------------------------------------------------------------------

remove_block_between_markers() {
  local file="$1"
  local name="$2"

  [[ -f "$file" ]] || return 0

  local begin end
  begin="^# --- POLARWAY BEGIN: ${name} ---$"
  end="^# --- POLARWAY END: ${name} ---$"

  if grep -Eq -- "$begin" "$file"; then
    echo "Removing Polarway block '${name}' from: $file"
    local tmp
    tmp="$(mktemp)"
    sed -E "/$begin/,/$end/d" "$file" > "$tmp"
    mv -- "$tmp" "$file"
  fi
}

# -----------------------------------------------------------------------------
# Backups restore logic
# -----------------------------------------------------------------------------

restore_backup_item() {
  local backup_dir="$1"
  local dst="$2"

  # Do not overwrite anything that exists
  [[ -e "$dst" || -L "$dst" ]] && return 0

  # New backup naming scheme: HOME__config__hypr
  local key
  key="${dst/#$HOME\//HOME\/}"
  key="${key//\//__}"

  if [[ -e "$backup_dir/$key" ]]; then
    echo "Restoring backup: $backup_dir/$key -> $dst"
    mkdir -p "$(dirname "$dst")"
    mv -v -- "$backup_dir/$key" "$dst"
    return 0
  fi

  # Old fallback: basename only
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

  echo "Backup marker found. Attempting restore from: $backup_dir"

  restore_backup_item "$backup_dir" "$HOME/.config/hypr"
  restore_backup_item "$backup_dir" "$HOME/.config/waybar"
  restore_backup_item "$backup_dir" "$HOME/.config/mako"
  restore_backup_item "$backup_dir" "$HOME/.config/rofi"

  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-wallpaper-random"
  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-power-menu"
}

# -----------------------------------------------------------------------------
# 1) Remove Polarway-inserted blocks from repo-managed Hyprland config
# -----------------------------------------------------------------------------

HYPR_REPO_CONF="$REPO_DIR/configs/hypr/hyprland.conf"

remove_block_between_markers "$HYPR_REPO_CONF" "wallpaper"
remove_block_between_markers "$HYPR_REPO_CONF" "power-menu"
remove_block_between_markers "$HYPR_REPO_CONF" "wlogout"
remove_block_between_markers "$HYPR_REPO_CONF" "terminate-user"
remove_block_between_markers "$HYPR_REPO_CONF" "screenshots"

# -----------------------------------------------------------------------------
# 2) Remove Polarway symlinks from the user's home
# -----------------------------------------------------------------------------

remove_link "$HOME/.config/hypr"
remove_link "$HOME/.config/waybar"
remove_link "$HOME/.config/mako"
remove_link "$HOME/.config/rofi"

remove_link "$HOME/.local/bin/polarway-wallpaper-random"
remove_link "$HOME/.local/bin/polarway-power-menu"

# -----------------------------------------------------------------------------
# 3) Restore backups
# -----------------------------------------------------------------------------
restore_backups

echo
echo "Done."
echo "Note: backups are kept inside the repo under .backup/ (not deleted)."