# Polarway

Polarway is a minimal Wayland / Hyprland dotfiles setup focused on a clean, polar aesthetic.

This repository contains my personal configuration for Hyprland and related tools, managed via symlinks for easy installation and version control.

The goal is a simple, reproducible desktop setup without heavy frameworks or installers.

> [!CAUTION]
> This setup is provided **as-is**, without warranty of any kind.  
> Use at your own risk. You are responsible for any changes made to your system.

---

## Features

- Hyprland configuration
- Waybar setup
- Mako notifications
- Wofi application launcher
- Helper scripts
- Symlink-based install system
- Automatic backups on install

---

## Repository Structure

```
polarway/
├── assets/
├── configs/
│   ├── hypr/
│   ├── waybar/
│   ├── mako/
│   ├── wofi/
│   └── scripts/
├── install.sh
├── uninstall.sh
├── LICENSE
└── README.md
```

All configs live inside `configs/`.  
During installation they are symlinked into `~/.config`.

---

## Requirements

- Hyprland
- Waybar
- Mako
- Wofi

Optional tools depending on your setup:

- brightnessctl
- playerctl
- wpctl (PipeWire)

---

## Installation

Clone the repository:

```
git clone https://github.com/eskopp/polarway.git
cd polarway
```

Run the installer:

```
./install.sh
```

What this does:

- Existing configs are backed up into `.backup/`
- Symlinks are created from this repo into `~/.config`
- Helper scripts are linked into `~/.local/bin`

After install:

- Restart Waybar:
```
pkill waybar; waybar &
```

- Reload Hyprland:
```
hyprctl reload
```

---

## Uninstall

To remove Polarway symlinks:

```
./uninstall.sh
```

Backups are kept inside the repository under `.backup/`.

---

## Philosophy

- No automatic package installation
- No hidden magic
- Everything is explicit
- Repo is the single source of truth
- Designed for Hyprland + Wayland first

This is not meant to be a universal theme — it is a personal, evolving setup.

---

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
