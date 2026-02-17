#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$REPO_DIR/.backup/$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_MARKER="$REPO_DIR/.polarway_last_backup"

WALLPAPER_URL="https://play-lh.googleusercontent.com/zbPObfDR7v0rTHlSjP-_gR6VjPqoSQlqcVA4nzMpdTqBXjIHTGKXMduvb3Ung5Zf-g=w7680-h4320"
LOCAL_WALLPAPER="$REPO_DIR/assets/wallpaper.jpg"
WALLPAPER_STORE_DIR="$HOME/.local/share/polarway"
WALLPAPER_STORE_FILE="$WALLPAPER_STORE_DIR/wallpaper.jpg"

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

download_wallpaper_if_needed() {
  # Prefer a local wallpaper file (not tracked by git), fallback to download.
  if [[ -f "$LOCAL_WALLPAPER" ]]; then
    echo "Wallpaper: using local file: $LOCAL_WALLPAPER"
    return 0
  fi

  mkdir -p "$WALLPAPER_STORE_DIR"

  if [[ -f "$WALLPAPER_STORE_FILE" ]]; then
    echo "Wallpaper: already present: $WALLPAPER_STORE_FILE"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    echo "Wallpaper: downloading via curl..."
    curl -L --fail --silent --show-error "$WALLPAPER_URL" -o "$WALLPAPER_STORE_FILE"
  elif command -v wget >/dev/null 2>&1; then
    echo "Wallpaper: downloading via wget..."
    wget -O "$WALLPAPER_STORE_FILE" "$WALLPAPER_URL"
  else
    echo "Wallpaper: skipped (no curl/wget installed)"
    return 0
  fi

  if [[ -s "$WALLPAPER_STORE_FILE" ]]; then
    echo "Wallpaper: saved to $WALLPAPER_STORE_FILE"
  else
    echo "Wallpaper: download failed or empty file, removing"
    rm -f "$WALLPAPER_STORE_FILE"
  fi
}

set_wallpaper_if_hyprland_running() {
  local wp=""

  if [[ -f "$LOCAL_WALLPAPER" ]]; then
    wp="$LOCAL_WALLPAPER"
  elif [[ -f "$WALLPAPER_STORE_FILE" ]]; then
    wp="$WALLPAPER_STORE_FILE"
  else
    return 0
  fi

  # Only try to set wallpaper if Hyprland IPC is available.
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    echo "Wallpaper: setting via hyprctl ($wp)"
    # Mode can be: fill, fit, stretch, center, tile
    hyprctl wallpaper , "$wp" fill || true
  else
    echo "Wallpaper: Hyprland not running, skipped setting wallpaper"
  fi
}

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

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

# Wallpaper (optional)
download_wallpaper_if_needed
set_wallpaper_if_hyprland_running

printf '%s\n' "$BACKUP_DIR" > "$BACKUP_MARKER"

echo
echo "Done."
echo "Tip: restart Waybar with: pkill waybar; waybar &"
echo "Tip: reload Hyprland with: hyprctl reload"
