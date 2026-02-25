# Polarway

Polarway is a minimal Hyprland/Wayland dotfiles setup focused on a clean, reproducible desktop configuration managed via symlinks.

This repo ships:
- Hyprland config
- Waybar config
- Rofi config + theme
- Mako notifications config
- Helper scripts (reload, wallpaper randomizer, power menu)
- Install/Uninstall scripts with automatic backups

> **Warning**
> This setup is provided **as-is**. Running `install.sh` will **replace** your existing configs by moving them into a backup directory inside this repo.

---

## Features

- **Hyprland** config with sensible defaults and keybinds
- **Waybar** status bar config
- **Rofi (Wayland)** app launcher config + theme
- **Mako** notifications config
- **swww** wallpapers with a random wallpaper helper
- Helper scripts for reloading and a simple power menu
- Symlink-based installation with automatic backups

---

## Requirements

- Arch-based system with `pacman`
- `sudo` privileges (for installing packages)
- A running Wayland session for wallpaper commands to take effect

The installer will install required packages via pacman, including:
- `hyprland`, `waybar`, `rofi-wayland`, `mako`, `swww`, `hyprlock`
- plus common Wayland utilities (grim/slurp/wl-clipboard, PipeWire stack, fonts, etc.)

---

## Repository structure

```
polarway/
├── configs/
│   ├── hypr/        # Hyprland config
│   ├── waybar/      # Waybar config
│   ├── rofi/        # Rofi config + theme
│   ├── mako/        # Mako config
│   └── scripts/     # Helper scripts (reload, wallpaper, power menu)
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Install

From inside the repo:

```bash
./install.sh
```

What `install.sh` does:
1. Installs baseline packages via pacman
2. Clones/updates `nord-background` into `~/git/nord-background`
3. Ensures helper scripts exist inside `configs/scripts/`
4. Wires Polarway autostart/keybind lines into the repo Hyprland config
5. Symlinks config folders into `~/.config/*`
6. Symlinks helper scripts into `~/.local/bin/*`
7. Writes a backup marker file: `.polarway_last_backup`

After installing, **log out and log back in** if you changed core Hyprland settings.

---

## Uninstall

```bash
./uninstall.sh
```

What `uninstall.sh` does:
- Removes Polarway-managed symlinks in `~/.config/*` and `~/.local/bin/*`
  (only if they point into this repo)
- Removes Polarway-inserted wiring lines from the repo Hyprland config
- Restores the most recent backup (if available)

Backups are **kept** in this repo under `.backup/` and are not deleted.

---

## Default keybinds

Keybinds live in `configs/hypr/hyprland.conf`.

Common ones in the Polarway wiring:
- **Win + R**: App launcher (Rofi)
- **Win + W**: Random wallpaper
- **Win + Escape**: Power menu (logout/reboot/shutdown)
- **Win + Shift + Q**: Logout (terminate user session)
- **Win + Shift + R**: Reload Hyprland + new wallpaper (if enabled)
- **Win + L**: Lock screen (if configured)

> Note: Your local `hyprland.conf` might contain additional binds beyond the wiring lines.

---

## Helper scripts

After install, helper scripts are available in `~/.local/bin/`:

- `polarway-wallpaper-random`  
  Sets a random wallpaper from `~/git/nord-background` using `swww`.

- `polarway-power-menu`  
  Rofi-based power menu (logout/reboot/shutdown).

- `polarway-reload`  
  Restarts Waybar and reloads Hyprland config.

---

## Backups

Before symlinks are created, existing targets are moved into:

```
polarway/.backup/YYYY-MM-DD_HH-MM-SS/
```

The most recent backup directory is recorded in:

```
polarway/.polarway_last_backup
```

Uninstall uses this marker to restore your previous configs *only if the destination path is missing*.

---

## License

See `LICENSE`.
