#!/bin/bash

nvim_deps=(
    nvim
    git
    curl
    ripgrep
    findutils
    lazygit
    luarocks
)

sudo pacman -S --color always --needed "${nvim_deps[@]}"

# required
mv ~/.config/nvim{,.bak}

# optional but recommended
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}

git clone https://github.com/LazyVim/starter ~/.config/nvim

rm -rf ~/.config/nvim/.git

nvim
