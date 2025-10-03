#!/bin/bash

pgks=(
  gdm-settings
  visual-studio-code-bin
)

for pkg in "${pgks[@]}"; do
  yay -S "$pkg"
done
