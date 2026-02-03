#!/bin/bash

pgks=(
  visual-studio-code-bin
)

for pkg in "${pgks[@]}"; do
  yay -S "$pkg"
done
