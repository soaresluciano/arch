#!/bin/bash

yay_deps=(
    base-devel
    git
)

sudo pacman -S --color always --needed "${yay_deps[@]}"

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
yay --version
cd ..
rm -rf yay
