#!/bin/bash

packages=(
  7zip
  bat
  bitwarden
  bleachbit
  btop
  clamav
  diffuse
  exa
  fastfetch
  firefox
  flameshot
  fzf
  gnome-firmware
  lazygit
  libreoffice-still
  obsidian
  rclone
  remmina
  steam
  seahorse
  tailscale
  vlc
  wine
)

for pkg in "${packages[@]}"; do
  echo "=== Installing $pkg ==="
  sudo pacman -S --color always --needed "$pkg"
done
