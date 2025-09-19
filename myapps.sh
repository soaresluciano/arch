#!/bin/bash

echo "Installing basic software..."
sudo pacman -S --needed \
  bat \
  chezmoi \
  exa \
  flatpak \
  fzf \
  fwupd \
  openssh
