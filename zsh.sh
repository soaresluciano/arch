#!/bin/bash

sudo pacman -S --noconfirm --needed \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    starship

# set zsh as default shell
chsh -s $(which zsh)

# create ~/.zprofile if it doesn't exist
[ ! -f ~/.zprofile ] && touch ~/.zprofile

# create .zshrc.d directory if it doesn't exist
[ ! -d ~/.zshrc.d ] && mkdir ~/.zshrc.d

# append sourcing logic to ~/.zshrc if not already present
if ! grep -q '# SOURCING' ~/.zshrc 2>/dev/null; then
    cat << 'EOF' >> ~/.zshrc
# SOURCING
for file in "$HOME/.zshrc.d"/*.zsh; do 
    [ -r "$file" ] && source "$file"
done
EOF
fi

# append starship logic to ~/.zshrc if not already present
if ! grep -q '# starship' ~/.zshrc 2>/dev/null; then
    cat << 'EOF' >> ~/.zshrc
# starship
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
EOF
fi

# link zsh-syntax-highlighting to ~/.zshrc.d so it is sourced automatically
ln -sf /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh "$HOME/.zshrc.d/zsh-syntax-highlighting.zsh"

# create alias file and append aliases
cat <<'EOF' >> "$HOME/.zshrc.d/alias.zsh"
alias ls="exa --icons"
alias disksize="df -h | grep '/dev/sd'"
alias dirsize="sudo du -shc ./*"
alias myalias="bat ~/.zshrc.d/aliases.zsh"
EOF
