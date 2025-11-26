#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_SOURCE="$SCRIPT_DIR/commands"
COMMANDS_TARGET="$HOME/.claude/commands"

echo "Setting up Claude Code commands..."

# Create target directory if it doesn't exist
if [ ! -d "$COMMANDS_TARGET" ]; then
    mkdir -p "$COMMANDS_TARGET"
    echo "Created $COMMANDS_TARGET"
fi

# Symlink all .md files
for file in "$COMMANDS_SOURCE"/*.md; do
    [ -e "$file" ] || continue

    filename=$(basename "$file")
    target="$COMMANDS_TARGET/$filename"

    if [ -L "$target" ]; then
        echo "Skipping $filename (symlink already exists)"
    elif [ -e "$target" ]; then
        echo "Warning: $filename already exists and is not a symlink, skipping"
    else
        ln -s "$file" "$target"
        echo "Linked $filename"
    fi
done

echo "Done!"
