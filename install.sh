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

ensure_nord_background_repo() {
  local git_dir="$HOME/git"
  local repo_dir="$git_dir/nord-background"
  local repo_url="https://github.com/ChrisTitusTech/nord-background.git"

  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install git and re-run."
    exit 1
  fi

  mkdir -p "$git_dir"

  if [[ -d "$repo_dir/.git" ]]; then
    echo "nord-background: updating in $repo_dir"
    git -C "$repo_dir" pull --ff-only
    return 0
  fi

  if [[ -e "$repo_dir" ]]; then
    echo "Error: $repo_dir exists but is not a git repository."
    echo "Please move/remove it and re-run."
    exit 1
  fi

  echo "nord-background: cloning into $repo_dir"
  git clone --depth 1 "$repo_url" "$repo_dir"
}

ensure_pacman_wayland_stack() {
  if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: pacman not found (this script is for Arch-based systems)."
    exit 1
  fi

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
  )

  echo "Installing Wayland/Hyprland baseline packages via pacman..."
  sudo pacman -Syu --needed "${pkgs[@]}"
}

ensure_random_wallpaper_on_start() {
  local wall_script_src="$REPO_DIR/configs/scripts/polarway-wallpaper-random"
  local hypr_conf_src="$REPO_DIR/configs/hypr/hyprland.conf"

  mkdir -p "$REPO_DIR/configs/scripts"
  mkdir -p "$REPO_DIR/configs/hypr"

  # Create/overwrite wallpaper script inside the repo (so it gets linked to ~/.local/bin)
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

# Pick a random wallpaper (jpg/jpeg/png)
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

  # Ensure Hyprland config exists in the repo
  [[ -f "$hypr_conf_src" ]] || touch "$hypr_conf_src"

  # Add exec-once lines only if missing
  if ! grep -qE '^\s*exec-once\s*=\s*swww\s+init\s*$' "$hypr_conf_src"; then
    printf '\nexec-once = swww init\n' >> "$hypr_conf_src"
  fi

  if ! grep -qE '^\s*exec-once\s*=\s*~/.local/bin/polarway-wallpaper-random\s*$' "$hypr_conf_src"; then
    printf 'exec-once = ~/.local/bin/polarway-wallpaper-random\n' >> "$hypr_conf_src"
  fi

  # Add a reload+wallpaper keybind only if missing (uses $mainMod if present in your config)
  if ! grep -qF 'hyprctl reload && ~/.local/bin/polarway-wallpaper-random' "$hypr_conf_src"; then
    printf '\nbind = $mainMod SHIFT, R, exec, hyprctl reload && ~/.local/bin/polarway-wallpaper-random\n' >> "$hypr_conf_src"
  fi
}

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# Install baseline packages first (so tools exist)
ensure_pacman_wayland_stack

# Ensure external wallpaper repository exists
ensure_nord_background_repo

# Ensure wallpaper script + Hyprland autostart/reload wiring exist in the repo configs
ensure_random_wallpaper_on_start

# Config symlinks
[[ -d "$REPO_DIR/configs/hypr"   ]] && link_one "$REPO_DIR/configs/hypr"   "$HOME/.config/hypr"
[[ -d "$REPO_DIR/configs/waybar" ]] && link_one "$REPO_DIR/configs/waybar" "$HOME/.config/waybar"
[[ -d "$REPO_DIR/configs/wofi"   ]] && link_one "$REPO_DIR/configs/wofi"   "$HOME/.config/wofi"
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
echo "Tip: force a new random wallpaper with: ~/.local/bin/polarway-wallpaper-random"