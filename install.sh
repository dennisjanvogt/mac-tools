#!/usr/bin/env bash

# Install (symlink) all tools in bin/ into ~/.local/bin/
# Usage: ./install.sh [--uninstall]

set -e

SRC_DIR="$(cd "$(dirname "$0")/bin" && pwd)"
DEST_DIR="$HOME/.local/bin"

mkdir -p "$DEST_DIR"

if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
    echo "Uninstalling mac-tools from $DEST_DIR..."
    for f in "$SRC_DIR"/*; do
        name=$(basename "$f")
        target="$DEST_DIR/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
            rm "$target"
            echo "  removed: $name"
        fi
    done
    echo "Done."
    exit 0
fi

echo "Installing mac-tools to $DEST_DIR..."

case ":$PATH:" in
    *":$DEST_DIR:"*) ;;
    *)
        echo
        echo "  Warning: $DEST_DIR is not on your PATH."
        echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        ;;
esac

skipped=0
linked=0
for f in "$SRC_DIR"/*; do
    name=$(basename "$f")
    target="$DEST_DIR/$name"

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
            echo "  ✓ $name (already linked)"
            linked=$((linked + 1))
            continue
        fi
        echo "  ! $name exists at $target — skipping (remove it manually if you want to overwrite)"
        skipped=$((skipped + 1))
        continue
    fi

    ln -s "$f" "$target"
    chmod +x "$f"
    echo "  + $name"
    linked=$((linked + 1))
done

echo
echo "Linked: $linked   Skipped: $skipped"
echo "Run 'cs' to see which CLI tools are available on your system."
