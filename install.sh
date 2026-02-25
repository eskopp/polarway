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

echo "Repo:      $REPO_DIR"
echo "Backups:   $BACKUP_DIR"
echo

# Ensure external wallpaper repository exists (used by your other scripts/config)
ensure_nord_background_repo

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