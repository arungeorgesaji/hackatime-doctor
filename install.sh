#!/usr/bin/env bash

set -e

TARGET="hackatime-doctor"
PLATFORM="$(uname -s)"

if [[ "$PLATFORM" == *"MINGW"* || "$PLATFORM" == *"MSYS"* || "$PLATFORM" == *"CYGWIN"* ]]; then
    BIN_EXT=".exe"
else
    BIN_EXT=""
fi

# Installation locations
case "$PLATFORM" in
    Linux*)
        PREFIX="${1:-/usr/local}"
        INSTALL_DIR="$PREFIX/bin"
        BIN_PATH="$INSTALL_DIR/$TARGET"
        CMD="install -m 755 bin/$TARGET$BIN_EXT \"$BIN_PATH\""
        ;;
    Darwin*)
        PREFIX="${1:-/usr/local}"
        INSTALL_DIR="$PREFIX/bin"
        BIN_PATH="$INSTALL_DIR/$TARGET"
        CMD="install -m 755 bin/$TARGET$BIN_EXT \"$BIN_PATH\""
        ;;
    MINGW*|MSYS*|CYGWIN*)
        INSTALL_DIR="${1:-/c/Program Files/hackatime-doctor}"
        BIN_PATH="$INSTALL_DIR/$TARGET$BIN_EXT"
        CMD="mkdir -p \"$INSTALL_DIR\" && cp bin/$TARGET$BIN_EXT \"$BIN_PATH\""
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

echo "Installing hackatime-doctor to: $BIN_PATH"
eval "$CMD"

case "$PLATFORM" in
    Linux*|Darwin*)
        echo "Successfully installed to $BIN_PATH"
        echo "Ensure $INSTALL_DIR is in your PATH"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "Successfully installed to $BIN_PATH"
        echo "Consider adding '$INSTALL_DIR' to your system PATH"
        ;;
esac
