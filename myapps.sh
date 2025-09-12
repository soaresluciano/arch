#!/bin/bash

echo "Installing basic software..."
sudo pacman -S \
  bat \
  exa \
  firefox \
  fzf \
  geany \
  htop \
  okular \
  starship \
  vlc

# extra software
read -p "Do you want to install extra software? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping extra software installation."
  exit 0
fi
echo "Installing extra software..."

sudo pacman -S \
  bleachbit \
  clamav \
  code \
  diffuse \
  exa \
  firefox \
  inkscape \
  kleopatra \
  qbittorrent \
  rclone \
  remmina \
  sqlitebrowser \
  steam \
  tailscale \
  wine
