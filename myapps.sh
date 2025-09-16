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
  fwupd \
  gnome-firmware \
  pavucontrol \
  vlc
