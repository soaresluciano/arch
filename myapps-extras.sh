#!/bin/bash

packages=(
  7zip
  bitwarden
  bleachbit
  btop
  clamav
  diffuse
  firefox
  geany
  gnome-firmware
  lazygit
  libreoffice-still
  obsidian
  rclone
  remmina
  tailscale
  vlc
  wine
)

for pkg in "${packages[@]}"; do
  sudo pacman -S --color always --needed "$pkg"
done