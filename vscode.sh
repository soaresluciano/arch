#!/bin/bash

flatpak install flathub com.visualstudio.code

FILE=~/.vscode/argv.json

if [ -f "$FILE" ]; then
    # Check if file has keys other than the opening and closing braces
    if grep -q '"[^"]\+"' "$FILE"; then
        # Insert with a comma before the last }
        sed -i '$!b;N;s/\(.*\)}/\1,\n  "password-store": "gnome-libsecret"\n}/' "$FILE"
    else
        # Insert as the only key
        echo -e '{\n  "password-store": "gnome-libsecret"\n}' > "$FILE"
    fi
else
    mkdir -p ~/.vscode
    echo -e '{\n  "password-store": "gnome-libsecret"\n}' > "$FILE"
fi
