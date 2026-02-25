#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Polarway Install Script
#
# What this script does:
#   1) Creates a timestamped backup of existing target paths (if present).
#   2) Writes a backup marker file so uninstall can restore the latest backup.
#   3) Creates symlinks from $HOME into the repo (configs + helper scripts).
#   4) Ensures Polarway-managed snippet blocks exist in the repo Hyprland config.
#
# Safety:
#   - Never deletes real files. Existing paths are moved into a backup dir.
#   - Only touches a small, explicit set of destinations.
# -----------------------------------------------------------------------------

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$REPO_DIR/.backup"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

timestamp() { date +"%Y-%m-%d_%H-%M-%S"; }

mkdir -p -- "$BACKUP_ROOT"

backup_dir="$BACKUP_ROOT/$(timestamp)"
mkdir -p -- "$backup_dir"

# Record last backup dir for uninstall restore
echo "$backup_dir" > "$BACKUP_MARKER"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

backup_item() {
  # Move an existing destination into the backup dir.
  # Uses stable naming: HOME__config__hypr
  local dst="$1"

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    return 0
  fi

  local key
  key="${dst/#$HOME\//HOME\/}"
  key="${key//\//__}"

  echo "Backing up: $dst -> $backup_dir/$key"
  mkdir -p -- "$(dirname "$backup_dir/$key")"
  mv -v -- "$dst" "$backup_dir/$key"
}

link_one() {
  # Create a symlink from src -> dst
  local src="$1"
  local dst="$2"

  mkdir -p -- "$(dirname "$dst")"
  ln -sfn -- "$src" "$dst"
  echo "Linked: $dst -> $src"
}

ensure_block_in_file() {
  # Ensure an exact marker block exists in a file.
  # If the block already exists, it will be replaced with the new content.
  local file="$1"
  local name="$2"
  local content="$3"

  mkdir -p -- "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"

  local begin end
  begin="# --- POLARWAY BEGIN: ${name} ---"
  end="# --- POLARWAY END: ${name} ---"

  local tmp
  tmp="$(mktemp)"

  if grep -Fq -- "$begin" "$file"; then
    # Replace existing block
    awk -v b="$begin" -v e="$end" -v c="$content" '
      BEGIN {inblk=0}
      $0==b {print b; print c; print e; inblk=1; next}
      $0==e {inblk=0; next}
      inblk==1 {next}
      {print}
    ' "$file" > "$tmp"
  else
    # Append new block at end
    cat "$file" > "$tmp"
    printf "\n%s\n%s\n%s\n" "$begin" "$content" "$end" >> "$tmp"
  fi

  mv -- "$tmp" "$file"
}

# -----------------------------------------------------------------------------
# 1) Backup existing targets
# -----------------------------------------------------------------------------

backup_item "$HOME/.config/hypr"
backup_item "$HOME/.config/waybar"
backup_item "$HOME/.config/mako"
backup_item "$HOME/.config/rofi"

backup_item "$HOME/.local/bin/polarway-wallpaper-random"
backup_item "$HOME/.local/bin/polarway-power-menu"

# -----------------------------------------------------------------------------
# 2) Create symlinks into the repo
# -----------------------------------------------------------------------------

link_one "$REPO_DIR/configs/hypr"   "$HOME/.config/hypr"
link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
link_one "$REPO_DIR/configs/mako"   "$HOME/.config/mako"
link_one "$REPO_DIR/configs/rofi"   "$HOME/.config/rofi"

# Helper scripts (repo-managed)
link_one "$REPO_DIR/configs/scripts/polarway-wallpaper-random" "$HOME/.local/bin/polarway-wallpaper-random"
link_one "$REPO_DIR/configs/scripts/polarway-power-menu"      "$HOME/.local/bin/polarway-power-menu"

chmod +x "$REPO_DIR/configs/scripts/polarway-wallpaper-random" || true
chmod +x "$REPO_DIR/configs/scripts/polarway-power-menu" || true
chmod +x "$HOME/.local/bin/polarway-wallpaper-random" || true
chmod +x "$HOME/.local/bin/polarway-power-menu" || true

# -----------------------------------------------------------------------------
# 3) Ensure Polarway blocks exist in Hyprland config (repo-managed)
# -----------------------------------------------------------------------------

HYPR_REPO_CONF="$REPO_DIR/configs/hypr/hyprland.conf"

# Wallpaper block
ensure_block_in_file "$HYPR_REPO_CONF" "wallpaper" "$(cat <<'EOF'
# Start a random wallpaper once (your script decides what to do)
exec-once = ~/.local/bin/polarway-wallpaper-random

# Manual wallpaper refresh
bind = $mainMod, W, exec, ~/.local/bin/polarway-wallpaper-random

# Reload Hyprland and refresh wallpaper
bind = $mainMod SHIFT, R, exec, hyprctl reload && ~/.local/bin/polarway-wallpaper-random
EOF
)"

# Power menu / lock / logout block
ensure_block_in_file "$HYPR_REPO_CONF" "power-menu" "$(cat <<'EOF'
# Lock / Power menu
bind = SUPER, L, exec, loginctl lock-session
bind = $mainMod, B, exec, hyprlock
bind = $mainMod, Escape, exec, ~/.local/bin/polarway-power-menu
EOF
)"

# Wlogout block
ensure_block_in_file "$HYPR_REPO_CONF" "wlogout" "$(cat <<'EOF'
# Logout menu
bind = $mainMod SHIFT, Q, exec, wlogout
EOF
)"

# Terminate user block (avoid conflict with SHIFT+Q by using CTRL+SHIFT+Q)
ensure_block_in_file "$HYPR_REPO_CONF" "terminate-user" "$(cat <<'EOF'
# Emergency: terminate user session (hard logout)
bind = $mainMod CTRL SHIFT, Q, exec, loginctl terminate-user $USER
EOF
)"

# Screenshots block (no AUR) — uses grimblast from hyprland-contrib
ensure_block_in_file "$HYPR_REPO_CONF" "screenshots" "$(cat <<'EOF'
# Screenshots (grimblast) - no AUR
# Reset potential conflicting Print binds (if any were defined earlier)
unbind = , Print
unbind = $mainMod, Print
unbind = $mainMod SHIFT, Print

# Print: select area -> file + clipboard
bind = , Print, exec, grimblast --notify --freeze copysave area "$HOME/Pictures/Screenshots/shot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Win+Print: active window -> file + clipboard
bind = $mainMod, Print, exec, grimblast --notify --freeze copysave active "$HOME/Pictures/Screenshots/shot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Win+Shift+Print: current output -> file + clipboard
bind = $mainMod SHIFT, Print, exec, grimblast --notify --freeze copysave output "$HOME/Pictures/Screenshots/shot_$(date +%Y-%m-%d_%H-%M-%S).png"
EOF
)"

# Ensure screenshot folder exists
mkdir -p "$HOME/Pictures/Screenshots"

echo
echo "Install complete."
echo "Backup created at: $backup_dir"
echo "Hyprland: run 'hyprctl reload' (or re-login) to apply config changes."  