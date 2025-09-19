#!/bin/bash

brew_deps=(
    base-devel
    procps-ng 
    curl 
    file 
    git
)

sudo pacman -S --color always --needed "${brew_deps[@]}"

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew --version
