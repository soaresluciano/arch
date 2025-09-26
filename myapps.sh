#!/bin/bash

packages=(
  7zip
  bitwarden
  bleachbit
  btop
  clamav
  diffuse
  fastfetch
  firefox
  flameshot
  gnome-calculator
  gnome-firmware
  gnome-software
  gnome-system-monitor
  gnome-text-editor
  gparted
  lazygit
  libreoffice-still
  obsidian
  rclone
  remmina
  steam
  tailscale
  vlc
  wine
  zathura-pdf-poppler
)

for pkg in "${packages[@]}"; do
  echo "=== Installing $pkg ==="
  sudo pacman -S --color always --needed "$pkg"
done
