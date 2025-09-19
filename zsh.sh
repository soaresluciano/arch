#!/bin/bash

packages=(
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    starship
)

sudo pacman -S --color always --needed "${packages[@]}"

# set zsh as default shell
chsh -s $(which zsh)

# create ~/.zprofile if it doesn't exist
[ ! -f ~/.zprofile ] && touch ~/.zprofile

# create ~/.zshenv if it doesn't exist
[ ! -f ~/.zshenv ] && touch ~/.zshenv
