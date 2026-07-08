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

link_dirs() {
    local source_dir="$1"
    local target_dir="$2"

    # Nothing to link if the source dir is absent
    [ -d "$source_dir" ] || return 0

    # Create target directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        echo "Created $target_dir"
    fi

    # Symlink each immediate subdirectory (e.g. skills, where each skill is a folder)
    for dir in "$source_dir"/*/; do
        [ -d "$dir" ] || continue

        name=$(basename "$dir")
        target="$target_dir/$name"

        if [ -L "$target" ]; then
            echo "Skipping $name (symlink already exists)"
        elif [ -e "$target" ]; then
            echo "Warning: $name already exists and is not a symlink, skipping"
        else
            ln -s "${dir%/}" "$target"
            echo "Linked $name"
        fi
    done
}

echo "Setting up Claude Code commands..."
link_md_files "$SCRIPT_DIR/commands" "$HOME/.claude/commands"

echo "Setting up Claude Code agents..."
link_md_files "$SCRIPT_DIR/agents" "$HOME/.claude/agents"

echo "Setting up Claude Code skills..."
link_dirs "$SCRIPT_DIR/skills" "$HOME/.claude/skills"

echo "Done!"
