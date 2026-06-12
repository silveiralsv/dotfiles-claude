#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_md_files() {
    local source_dir="$1"
    local target_dir="$2"

    # Create target directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        echo "Created $target_dir"
    fi

    # Symlink all .md files
    for file in "$source_dir"/*.md; do
        [ -e "$file" ] || continue

        filename=$(basename "$file")
        target="$target_dir/$filename"

        if [ -L "$target" ]; then
            echo "Skipping $filename (symlink already exists)"
        elif [ -e "$target" ]; then
            echo "Warning: $filename already exists and is not a symlink, skipping"
        else
            ln -s "$file" "$target"
            echo "Linked $filename"
        fi
    done
}

echo "Setting up Claude Code commands..."
link_md_files "$SCRIPT_DIR/commands" "$HOME/.claude/commands"

echo "Setting up Claude Code agents..."
link_md_files "$SCRIPT_DIR/agents" "$HOME/.claude/agents"

echo "Done!"
