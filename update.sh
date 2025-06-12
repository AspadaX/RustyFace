#!/bin/bash

# =====================
# RustyFace Update Script (Template)
# =====================
# This script updates the installed CLI tool to the latest release from GitHub.
# To reuse for other projects, change the variables in the CONFIGURATION section.

set -eo pipefail

# ------------- CONFIGURATION -------------
REPO="AspadaX/RustyFace"           # GitHub repo (e.g. owner/repo)
BINARY_NAME="rustyface"            # Name of the binary (no extension)
PROJECT_DESC="RustyFace CLI tool"  # Description for prompts
# ------------- END CONFIG ---------------

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
IS_WINDOWS=false
if [[ "$OS" == *"mingw"* || "$OS" == *"msys"* || "$OS" == *"cygwin"* ]]; then
  IS_WINDOWS=true
  OS="windows"
fi

case $ARCH in
  x86_64|amd64) ARCH="x86_64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Compose filename for download
case $OS in
  linux*)   FILENAME="$BINARY_NAME-Linux-$ARCH.tar.gz" ;;
  darwin*)  FILENAME="$BINARY_NAME-macOS-$ARCH.tar.gz" ;;
  windows*) FILENAME="$BINARY_NAME-Windows-x86_64.zip" ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
echo "Fetching latest release info for $PROJECT_DESC..."
RELEASE_INFO=$(curl -s -f $RELEASE_URL)
if [ $? -ne 0 ]; then
  echo "Error: Could not fetch release info from GitHub."; exit 1
fi

DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "https://.*/$FILENAME" | head -1)
if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Error: Could not find download URL for $FILENAME."; exit 1
fi
SHA_URL="$DOWNLOAD_URL.sha256"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Download binary and checksum
curl -L -o "$TMPDIR/$FILENAME" "$DOWNLOAD_URL"
curl -L -o "$TMPDIR/$FILENAME.sha256" "$SHA_URL" || echo "(No checksum found, skipping verification)"

if [[ -f "$TMPDIR/$FILENAME.sha256" ]]; then
  echo "Verifying checksum..."
  expected_hash=$(awk '{print $1}' "$TMPDIR/$FILENAME.sha256")
  if command -v shasum >/dev/null 2>&1; then
    actual_hash=$(shasum -a 256 "$TMPDIR/$FILENAME" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    actual_hash=$(sha256sum "$TMPDIR/$FILENAME" | awk '{print $1}')
  else
    echo "Warning: No SHA256 tool found. Skipping verification."
    actual_hash=$expected_hash
  fi
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo "Checksum verification failed!"; exit 1
  fi
fi

echo "Extracting..."
if $IS_WINDOWS; then
  unzip -o "$TMPDIR/$FILENAME" -d "$TMPDIR"
  BIN_PATH=$(find "$TMPDIR" -name "$BINARY_NAME.exe" -type f -print -quit)
else
  tar xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"
  BIN_PATH=$(find "$TMPDIR" -name "$BINARY_NAME" -type f -print -quit)
fi

if [[ -z "$BIN_PATH" ]]; then
  echo "Error: Could not find binary after extraction."; exit 1
fi

# Install (overwrite)
if $IS_WINDOWS; then
  INSTALL_DIR="$HOME/bin"
  mkdir -p "$INSTALL_DIR"
  mv -f "$BIN_PATH" "$INSTALL_DIR/$BINARY_NAME.exe"
else
  INSTALL_DIR="/usr/local/bin"
  sudo mv -f "$BIN_PATH" "$INSTALL_DIR/$BINARY_NAME"
  sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
fi

echo "$BINARY_NAME has been updated to the latest version in $INSTALL_DIR."
echo "Run '$BINARY_NAME --version' to verify the update."
