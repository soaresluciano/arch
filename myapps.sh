#!/bin/bash

echo "Installing basic software..."
sudo pacman -S --needed \
  7zip \
  bat \
  bitwarden \
  btop \
  chezmoi \
  exa \
  firefox \
  flatpak \
  fzf \
  git \
  geany \
  neovim \
  pavucontrol \
  okular \
  vlc

# extra software
read -p "Do you want to install extra software? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping extra software installation."
  exit 0
fi
echo "Installing extra software..."

sudo pacman -S --needed \
  bleachbit \
  clamav \
  code \
  diffuse \
  distrobox \
  inkscape \
  kleopatra \
  lazygit \
  libreoffice-still \
  man-db \
  man-pages \
  qbittorrent \
  obsidian \
  openssh \
  podman-desktop \
  rclone \
  remmina \
  rsync \
  sqlitebrowser \
  steam \
  tailscale \
  wine
