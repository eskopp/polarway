#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Polarway Install Script (English, improved + well-commented)
#
# What this script does:
#   1) Installs a baseline Wayland/Hyprland stack via pacman (Arch-based).
#   2) Clones or updates the nord-background wallpaper repository.
#   3) Ensures helper scripts exist inside this repo (wallpaper randomizer, power menu).
#   4) Wires Polarway-specific autostart + keybinds into the repo Hyprland config.
#   5) Symlinks Polarway configs into ~/.config/* (hypr/waybar/mako/rofi).
#   6) Symlinks helper scripts into ~/.local/bin.
#   7) Creates backups of any existing targets before replacing them.
#
# Design decisions:
#   - Uses symlinks so the repo is the single source of truth.
#   - Backups are stored in $REPO_DIR/.backup/<timestamp>/ and never deleted.
#   - Adds Polarway wiring inside the repo config (configs/hypr/hyprland.conf),
#     so uninstall can cleanly remove it without touching unrelated user files.
# -----------------------------------------------------------------------------

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$REPO_DIR/.backup/$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

_die() {
  echo "Error: $*" >&2
  exit 1
}

_mkdir_parent() {
  # Create the parent directory of a given path.
  mkdir -p "$(dirname "$1")"
}

_backup_existing() {
  # Move an existing destination (file/dir/symlink) into our backup directory.
  # The backup name is normalized to avoid collisions (e.g. multiple "config" files).
  local dst="$1"
  local rel

  [[ -e "$dst" || -L "$dst" ]] || return 0

  mkdir -p "$BACKUP_DIR"

  rel="${dst/#$HOME\//HOME\/}"
  rel="${rel//\//__}"

  mv -v -T "$dst" "$BACKUP_DIR/$rel"
}

link_one() {
  # Create or replace a symlink: dst -> src.
  # Before linking, back up whatever is currently at dst.
  local src="$1"
  local dst="$2"

  _mkdir_parent "$dst"
  _backup_existing "$dst"
  ln -sfnv "$src" "$dst"
}

append_line_if_missing() {
  # Append a line to a file if it is not already present.
  #
  # Args:
  #   file  - the file to edit (created if missing)
  #   line  - the line to append
  #   match - optional substring to search for (instead of matching the full line)
  local file="$1"
  local line="$2"
  local match="${3:-}"

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"

  if [[ -n "$match" ]]; then
    grep -qF -- "$match" "$file" && return 0
  else
    grep -qF -- "$line" "$file" && return 0
  fi

  printf '\n%s\n' "$line" >> "$file"
}

# -----------------------------------------------------------------------------
# External repos / packages
# -----------------------------------------------------------------------------

ensure_nord_background_repo() {
  # Clone/update the Nord background wallpaper repo into $HOME/git/nord-background.
  local git_dir="$HOME/git"
  local repo_dir="$git_dir/nord-background"
  local repo_url="https://github.com/ChrisTitusTech/nord-background.git"

  command -v git >/dev/null 2>&1 || _die "git is not installed. Please install git and re-run."

  mkdir -p "$git_dir"

  if [[ -d "$repo_dir/.git" ]]; then
    echo "nord-background: updating in $repo_dir"
    git -C "$repo_dir" pull --ff-only
    return 0
  fi

  if [[ -e "$repo_dir" ]]; then
    _die "$repo_dir exists but is not a git repository. Please move/remove it and re-run."
  fi

  echo "nord-background: cloning into $repo_dir"
  git clone --depth 1 "$repo_url" "$repo_dir"
}

ensure_pacman_wayland_stack() {
  # Install baseline packages on Arch-based systems.
  #
  # Note:
  #   - We keep the list explicit and stable for reproducible installs.
  #   - swww is used for wallpapers; it requires a daemon (swww-daemon).
  command -v pacman >/dev/null 2>&1 || _die "pacman not found (this script is for Arch-based systems)."

  local pkgs=(
    # compositor + portals + auth agent
    hyprland
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    polkit-kde-agent

    # bar / launcher / notifications
    waybar
    rofi-wayland
    mako

    # wallpapers
    swww

    # screenshots / clipboard
    grim
    slurp
    wl-clipboard
    swappy

    # audio (PipeWire)
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    pavucontrol

    # network / bluetooth
    networkmanager
    network-manager-applet
    bluez
    bluez-utils

    # common Wayland helpers
    xdg-utils
    qt5-wayland
    qt6-wayland
    glfw-wayland

    # fonts for Waybar icons/glyphs
    ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols

    # lock screen
    hyprlock
  )

  echo "Installing Wayland/Hyprland baseline packages via pacman..."
  sudo pacman -Syu --needed "${pkgs[@]}"
}

# -----------------------------------------------------------------------------
# Helper scripts (wallpaper + power menu)
# -----------------------------------------------------------------------------

ensure_random_wallpaper_script() {
  # Creates/updates the wallpaper randomizer script inside the repo.
  # This script ensures swww-daemon is running and then sets a random image.
  local wall_script_src="$REPO_DIR/configs/scripts/polarway-wallpaper-random"

  mkdir -p "$REPO_DIR/configs/scripts"

  cat > "$wall_script_src" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/git/nord-background}"

# Exit gracefully if the wallpaper directory is missing.
if [[ ! -d "$WALL_DIR" ]]; then
  echo "polarway-wallpaper-random: directory not found: $WALL_DIR" >&2
  exit 0
fi

# Exit gracefully if swww is not installed.
if ! command -v swww >/dev/null 2>&1; then
  echo "polarway-wallpaper-random: swww not installed" >&2
  exit 0
fi

# Ensure swww-daemon is running (reliable approach).
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww-daemon >/dev/null 2>&1 &
  disown || true
  sleep 0.2
fi

# If the daemon isn't responsive, bail out quietly.
if ! swww query >/dev/null 2>&1; then
  echo "polarway-wallpaper-random: swww-daemon not responding" >&2
  exit 0
fi

# Pick a random wallpaper from the top level of WALL_DIR (jpg/jpeg/png).
# Using -print0 / shuf -z ensures paths with spaces are handled safely.
wp="$(
  find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 \
  | shuf -z -n 1 \
  | tr -d '\0'
)"

if [[ -z "${wp:-}" || ! -f "$wp" ]]; then
  echo "polarway-wallpaper-random: no images found in $WALL_DIR" >&2
  exit 0
fi

# Apply wallpaper with a transition; fall back if transition fails.
swww img "$wp" --transition-type grow --transition-duration 0.6 >/dev/null 2>&1 || \
swww img "$wp" >/dev/null 2>&1
EOF

  chmod +x "$wall_script_src"
}

ensure_rofi_power_menu_script() {
  # Creates/updates a simple Rofi-based power menu script inside the repo.
  local power_script_src="$REPO_DIR/configs/scripts/polarway-power-menu"

  mkdir -p "$REPO_DIR/configs/scripts"

  cat > "$power_script_src" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v rofi >/dev/null 2>&1; then
  echo "polarway-power-menu: rofi not installed" >&2
  exit 0
fi

choice="$(
  printf "logout\nreboot\nshutdown\n" \
  | rofi -dmenu -p "power"
)"

case "$choice" in
  logout)
    loginctl terminate-user "$USER"
    ;;
  reboot)
    systemctl reboot
    ;;
  shutdown)
    systemctl poweroff
    ;;
  *)
    exit 0
    ;;
esac
EOF

  chmod +x "$power_script_src"
}

# -----------------------------------------------------------------------------
# Repo config wiring (Hyprland)
# -----------------------------------------------------------------------------

ensure_hyprland_wiring_in_repo() {
  # Append Polarway autostart and binds into the repo-managed Hyprland config.
  #
  # Important:
  #   - We wire into the repo config (configs/hypr/hyprland.conf) because
  #     ~/.config/hypr will be symlinked to it.
  #   - We keep a small, predictable set of lines so uninstall can remove them
  #     without touching unrelated user config.
  local hypr_conf_src="$REPO_DIR/configs/hypr/hyprland.conf"

  mkdir -p "$REPO_DIR/configs/hypr"
  [[ -f "$hypr_conf_src" ]] || touch "$hypr_conf_src"

  # Autostart: ensure daemon + set random wallpaper once.
  # We start the daemon explicitly (more reliable than "swww init" on some setups).
  append_line_if_missing \
    "$hypr_conf_src" \
    "exec-once = pgrep -x swww-daemon >/dev/null 2>&1 || swww-daemon" \
    "pgrep -x swww-daemon"

  append_line_if_missing \
    "$hypr_conf_src" \
    "exec-once = ~/.local/bin/polarway-wallpaper-random" \
    "~/.local/bin/polarway-wallpaper-random"

  # Keybinds:
  # - Reload + new wallpaper (Win+Shift+R)
  append_line_if_missing \
    "$hypr_conf_src" \
    "bind = \$mainMod SHIFT, R, exec, hyprctl reload && ~/.local/bin/polarway-wallpaper-random" \
    "hyprctl reload && ~/.local/bin/polarway-wallpaper-random"

  # - Quick wallpaper change (Win+W)
  append_line_if_missing \
    "$hypr_conf_src" \
    "bind = \$mainMod, W, exec, ~/.local/bin/polarway-wallpaper-random" \
    "bind = \$mainMod, W, exec, ~/.local/bin/polarway-wallpaper-random"

  # - Power menu (Win+Escape)
  append_line_if_missing \
    "$hypr_conf_src" \
    "bind = \$mainMod, Escape, exec, ~/.local/bin/polarway-power-menu" \
    "~/.local/bin/polarway-power-menu"

  # - Direct logout (Win+Shift+Q)
  append_line_if_missing \
    "$hypr_conf_src" \
    "bind = \$mainMod SHIFT, Q, exec, loginctl terminate-user \$USER" \
    "loginctl terminate-user"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# 1) Install baseline packages first (Arch)
ensure_pacman_wayland_stack

# 2) Ensure nord-background repo exists (wallpapers)
ensure_nord_background_repo

# 3) Generate helper scripts inside the repo (linked to ~/.local/bin later)
ensure_random_wallpaper_script
ensure_rofi_power_menu_script

# 4) Wire autostart + keybinds into repo Hyprland config
ensure_hyprland_wiring_in_repo

# 5) Symlink config directories into ~/.config/*
[[ -d "$REPO_DIR/configs/hypr"   ]] && link_one "$REPO_DIR/configs/hypr"   "$HOME/.config/hypr"
[[ -d "$REPO_DIR/configs/waybar" ]] && link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
[[ -d "$REPO_DIR/configs/mako"   ]] && link_one "$REPO_DIR/configs/mako"   "$HOME/.config/mako"
[[ -d "$REPO_DIR/configs/rofi"   ]] && link_one "$REPO_DIR/configs/rofi"   "$HOME/.config/rofi"

# 6) Symlink helper scripts into ~/.local/bin
if [[ -d "$REPO_DIR/configs/scripts" ]]; then
  mkdir -p "$HOME/.local/bin"
  for f in "$REPO_DIR"/configs/scripts/*; do
    [[ -f "$f" ]] || continue
    link_one "$f" "$HOME/.local/bin/$(basename "$f")"
  done
fi

# Record the backup directory path so uninstall can restore the latest backup.
printf '%s\n' "$BACKUP_DIR" > "$BACKUP_MARKER"

echo
echo "Done."
echo "Tips:"
echo "  - Reload Hyprland:            hyprctl reload"
echo "  - Restart Waybar:             pkill waybar; waybar &"
echo "  - Force new random wallpaper: ~/.local/bin/polarway-wallpaper-random"
echo "  - Power menu:                 Win+Escape"
echo "  - Wallpaper random:           Win+W"
echo "  - Logout:                     Win+Shift+Q"