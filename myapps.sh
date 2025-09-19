#!/bin/bash

basic_apps=(
  bat
  chezmoi
  exa
  flatpak
  fzf
  fwupd
  openssh
  reflector
)

echo "Installing basic software..."
sudo pacman -S --color always --needed "${basic_apps[@]}"
