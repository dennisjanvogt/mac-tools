#!/usr/bin/env bash

# Install symlinks for mac-tools:
#   bin/<tool>     ->  ~/.local/bin/<tool>
#   src/<app>      ->  ~/.local/src/<app>     (so the ConsultingOS CLIs can swiftc-build)
#
# Usage: ./install.sh [--uninstall]

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SRC="$REPO_DIR/bin"
SRC_SRC="$REPO_DIR/src"
BIN_DEST="$HOME/.local/bin"
SRC_DEST="$HOME/.local/src"

mkdir -p "$BIN_DEST" "$SRC_DEST"

uninstall() {
    echo "Uninstalling mac-tools..."
    for f in "$BIN_SRC"/*; do
        name=$(basename "$f")
        target="$BIN_DEST/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
            rm "$target"
            echo "  removed bin: $name"
        fi
    done
    if [ -d "$SRC_SRC" ]; then
        for d in "$SRC_SRC"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            target="$SRC_DEST/$name"
            if [ -L "$target" ] && [ "$(readlink "$target")" = "${d%/}" ]; then
                rm "$target"
                echo "  removed src: $name"
            fi
        done
    fi
    echo "Done."
}

if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
    uninstall
    exit 0
fi

echo "Installing mac-tools..."

case ":$PATH:" in
    *":$BIN_DEST:"*) ;;
    *)
        echo
        echo "  Warning: $BIN_DEST is not on your PATH."
        echo "  Add this to your shell profile (~/.zshrc or ~/.bashrc):"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        ;;
esac

link() {
    local src="$1" dest="$2" kind="$3"
    local name=$(basename "$src")
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "  ✓ $kind/$name (already linked)"
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        echo "  ! $kind/$name exists at $dest — skipping"
        return 1
    fi
    ln -s "$src" "$dest"
    [ -f "$src" ] && chmod +x "$src"
    echo "  + $kind/$name"
}

# bin/
for f in "$BIN_SRC"/*; do
    link "$f" "$BIN_DEST/$(basename "$f")" "bin" || true
done

# src/  (only needed for ConsultingOS apps; safe to skip if you don't use them)
if [ -d "$SRC_SRC" ]; then
    echo
    for d in "$SRC_SRC"/*/; do
        [ -d "$d" ] || continue
        d="${d%/}"
        link "$d" "$SRC_DEST/$(basename "$d")" "src" || true
    done
fi

echo
echo "Run 'cs' to see which CLI tools are now available."
echo
echo "ConsultingOS apps (dash/kanban/tafel/zeit/canwa/literatur/termine):"
echo "  Source code is now linked at ~/.local/src/<name>/. To build:"
echo "    <tool> build      # e.g. 'kanban build'"
echo "  They still require access to the private API at https://1o618.com — they"
echo "  will compile but auth-protected calls will fail without that backend."
echo "  For canwa, run once: cd ~/.local/src/canwa-web && npm install && npx vite build"
