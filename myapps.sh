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
  lazygit
  libreoffice-still
  obsidian
  rclone
  remmina
  steam
  tailscale
  vlc
  wine
)

for pkg in "${packages[@]}"; do
  echo "=== Installing $pkg ==="
  sudo pacman -S --color always --needed "$pkg"
done
