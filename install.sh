#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$REPO_DIR/.backup/$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

# ----------------------------
# Helpers
# ----------------------------

_die() {
  echo "Error: $*" >&2
  exit 1
}

_mkdir_parent() {
  mkdir -p "$(dirname "$1")"
}

_backup_existing() {
  local dst="$1"
  local rel

  [[ -e "$dst" || -L "$dst" ]] || return 0

  mkdir -p "$BACKUP_DIR"

  # Build a stable relative path for backups (avoid collisions like multiple "config" files).
  rel="${dst/#$HOME\//HOME\/}"
  rel="${rel//\//__}"

  mv -v -T "$dst" "$BACKUP_DIR/$rel"
}

link_one() {
  local src="$1"
  local dst="$2"

  _mkdir_parent "$dst"
  _backup_existing "$dst"
  ln -sfnv "$src" "$dst"
}

append_line_if_missing() {
  local file="$1"
  local line="$2"
  local match="${3:-}"

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"

  if [[ -n "$match" ]]; then
    grep -qF "$match" "$file" && return 0
  else
    grep -qF "$line" "$file" && return 0
  fi

  printf '\n%s\n' "$line" >> "$file"
}

# ----------------------------
# External repos / packages
# ----------------------------

ensure_nord_background_repo() {
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

# ----------------------------
# Wallpaper + power menu
# ----------------------------

ensure_random_wallpaper_script() {
  local wall_script_src="$REPO_DIR/configs/scripts/polarway-wallpaper-random"

  mkdir -p "$REPO_DIR/configs/scripts"

  cat > "$wall_script_src" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/git/nord-background}"

if [[ ! -d "$WALL_DIR" ]]; then
  echo "polarway-wallpaper-random: directory not found: $WALL_DIR" >&2
  exit 0
fi

if ! command -v swww >/dev/null 2>&1; then
  echo "polarway-wallpaper-random: swww not installed" >&2
  exit 0
fi

# Ensure swww daemon is running
swww query >/dev/null 2>&1 || swww init >/dev/null 2>&1 || true

wp="$(
  find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 \
  | shuf -z -n 1 \
  | tr -d '\0'
)"

if [[ -z "${wp:-}" || ! -f "$wp" ]]; then
  echo "polarway-wallpaper-random: no images found in $WALL_DIR" >&2
  exit 0
fi

# Transition is optional; fallback if it fails
swww img "$wp" --transition-type grow --transition-duration 0.6 >/dev/null 2>&1 || \
swww img "$wp" >/dev/null 2>&1
EOF

  chmod +x "$wall_script_src"
}

ensure_rofi_power_menu_script() {
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

ensure_hyprland_wiring_in_repo() {
  local hypr_conf_src="$REPO_DIR/configs/hypr/hyprland.conf"

  mkdir -p "$REPO_DIR/configs/hypr"
  [[ -f "$hypr_conf_src" ]] || touch "$hypr_conf_src"

  # Autostart: swww daemon + random wallpaper
  append_line_if_missing "$hypr_conf_src" "exec-once = swww init" "exec-once = swww init"
  append_line_if_missing "$hypr_conf_src" "exec-once = ~/.local/bin/polarway-wallpaper-random" "~/.local/bin/polarway-wallpaper-random"

  # Keybinds:
  # - Reload + new wallpaper (Win+Shift+R)
  append_line_if_missing \
    "$hypr_conf_src" \
    "bind = \$mainMod SHIFT, R, exec, hyprctl reload && ~/.local/bin/polarway-wallpaper-random" \
    "hyprctl reload && ~/.local/bin/polarway-wallpaper-random"

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

# ----------------------------
# Main
# ----------------------------

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# 1) Install baseline packages first
ensure_pacman_wayland_stack

# 2) Ensure nord-background repo exists
ensure_nord_background_repo

# 3) Generate helper scripts inside the repo (they will be linked to ~/.local/bin)
ensure_random_wallpaper_script
ensure_rofi_power_menu_script

# 4) Wire autostart + keybinds into repo Hyprland config
ensure_hyprland_wiring_in_repo

# 5) Config symlinks
[[ -d "$REPO_DIR/configs/hypr"   ]] && link_one "$REPO_DIR/configs/hypr"   "$HOME/.config/hypr"
[[ -d "$REPO_DIR/configs/waybar" ]] && link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
[[ -d "$REPO_DIR/configs/mako"   ]] && link_one "$REPO_DIR/configs/mako"   "$HOME/.config/mako"
[[ -d "$REPO_DIR/configs/rofi"   ]] && link_one "$REPO_DIR/configs/rofi"   "$HOME/.config/rofi"


# 6) Helper scripts -> ~/.local/bin
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
echo "Tips:"
echo "  - Reload Hyprland:           hyprctl reload"
echo "  - Restart Waybar:            pkill waybar; waybar &"
echo "  - Force new random wallpaper ~/.local/bin/polarway-wallpaper-random"
echo "  - Power menu:                Win+Escape"
echo "  - Logout:                    Win+Shift+Q"