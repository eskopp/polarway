```bash
#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Polarway Uninstall Script (English, well-commented)
#
# Goals:
#   - Remove only Polarway-managed symlinks from the user's home directory.
#   - Remove Polarway-inserted config snippets from Polarway-managed config files.
#   - Restore backups created by install.sh (if present).
#   - Avoid deleting or modifying unrelated user files.
#
# Notes on safety:
#   - This script ONLY removes symlinks that point into the Polarway repo.
#   - It will NOT delete real directories/files that are not symlinks.
#   - It restores backups only if the destination path does not exist anymore.
# -----------------------------------------------------------------------------

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

is_polarway_link() {
  # Returns 0 if $1 is a symlink pointing somewhere inside $REPO_DIR.
  local dst="$1"
  [[ -L "$dst" ]] || return 1

  local resolved
  resolved="$(readlink -f -- "$dst")"
  [[ "$resolved" == "$REPO_DIR/"* ]]
}

remove_link() {
  # Remove a symlink if and only if it points into this repo.
  local dst="$1"
  if is_polarway_link "$dst"; then
    echo "Removing Polarway symlink: $dst"
    rm -v -- "$dst"
  else
    echo "Skip (not a Polarway symlink): $dst"
  fi
}

remove_lines_matching() {
  # Removes lines that contain a given fixed substring from a file.
  #
  # This is used to remove Polarway-inserted "append_line_if_missing" snippets
  # from the repo-managed Hyprland config (configs/hypr/hyprland.conf).
  #
  # It is intentionally conservative:
  #   - If the file doesn't exist, do nothing.
  #   - Only removes lines containing the exact substring provided.
  local file="$1"
  local needle="$2"

  [[ -f "$file" ]] || return 0

  if grep -Fq -- "$needle" "$file"; then
    echo "Removing lines from $file matching: $needle"
    local tmp
    tmp="$(mktemp)"
    grep -Fv -- "$needle" "$file" > "$tmp"
    mv -- "$tmp" "$file"
  fi
}

restore_backup_item() {
  # Restore a single destination from backup if it is currently missing.
  #
  # install.sh uses a stable naming scheme to store backups:
  #   "$HOME/.config/hypr" -> "HOME__config__hypr"
  # plus an older scheme fallback by basename.
  local backup_dir="$1"
  local dst="$2"

  # If the destination already exists (or is a symlink), do not overwrite it.
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
  # Restore the last backup made by install.sh (if available).
  #
  # The marker file contains the absolute path to the last backup directory:
  #   .polarway_last_backup -> /path/to/repo/.backup/YYYY-MM-DD_HH-MM-SS
  [[ -f "$BACKUP_MARKER" ]] || return 0

  local backup_dir
  backup_dir="$(cat "$BACKUP_MARKER")"
  [[ -d "$backup_dir" ]] || return 0

  echo "Backup marker found. Attempting restore from: $backup_dir"

  # Restore config dirs if they were backed up
  restore_backup_item "$backup_dir" "$HOME/.config/hypr"
  restore_backup_item "$backup_dir" "$HOME/.config/waybar"
  restore_backup_item "$backup_dir" "$HOME/.config/mako"
  restore_backup_item "$backup_dir" "$HOME/.config/rofi"

  # Restore helper scripts if they were backed up
  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-wallpaper-random"
  restore_backup_item "$backup_dir" "$HOME/.local/bin/polarway-power-menu"
}

# -----------------------------------------------------------------------------
# 1) Remove Polarway-inserted snippets from repo-managed Hyprland config
# -----------------------------------------------------------------------------
#
# In your install.sh you append these lines to:
#   $REPO_DIR/configs/hypr/hyprland.conf
#
# Even though $HOME/.config/hypr is a symlink to the repo directory, it's nice
# to clean the repo config as well so nothing "weird" remains after uninstall.
#
# If you prefer to keep the repo config untouched, you can remove this section.
#

HYPR_REPO_CONF="$REPO_DIR/configs/hypr/hyprland.conf"

# Autostart wiring
remove_lines_matching "$HYPR_REPO_CONF" "exec-once = swww init"
remove_lines_matching "$HYPR_REPO_CONF" "~/.local/bin/polarway-wallpaper-random"

# Keybind wiring
remove_lines_matching "$HYPR_REPO_CONF" "hyprctl reload && ~/.local/bin/polarway-wallpaper-random"
remove_lines_matching "$HYPR_REPO_CONF" "~/.local/bin/polarway-power-menu"
remove_lines_matching "$HYPR_REPO_CONF" "loginctl terminate-user"

# -----------------------------------------------------------------------------
# 2) Remove Polarway symlinks from the user's home
# -----------------------------------------------------------------------------
#
# These are created by install.sh via link_one().
# We remove only symlinks that point into the Polarway repo.
#

remove_link "$HOME/.config/hypr"
remove_link "$HOME/.config/waybar"
remove_link "$HOME/.config/mako"
remove_link "$HOME/.config/rofi"

remove_link "$HOME/.local/bin/polarway-wallpaper-random"
remove_link "$HOME/.local/bin/polarway-power-menu"

# -----------------------------------------------------------------------------
# 3) Restore backups (if present)
# -----------------------------------------------------------------------------
restore_backups

echo
echo "Done."
echo "Note: backups are kept inside the repo under .backup/ (not deleted)."
```
