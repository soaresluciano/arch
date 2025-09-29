#!/bin/bash
set -e

sudo pacman -S --color always --needed chezmoi
chezmoi init soaresluciano && chezmoi apply
