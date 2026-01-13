#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib/noir-build-tools"

mkdir -p "$BIN_DIR" "$LIB_DIR"

# Install binaries
cp bin/nbt "$BIN_DIR/"
chmod +x "$BIN_DIR/nbt"

# Install libraries
mkdir -p "$LIB_DIR/commands"
cp lib/*.sh "$LIB_DIR/"
cp lib/commands/* "$LIB_DIR/commands/"
chmod +x "$LIB_DIR/commands/"*

echo "Installed nbt to $BIN_DIR"
echo "Installed libraries to $LIB_DIR"
echo "Ensure $BIN_DIR is in your PATH"
