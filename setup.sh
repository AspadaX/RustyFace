#!/bin/bash

# =====================
# RustyFace Setup Script (Template)
# =====================
# This script installs the latest release of a GitHub CLI tool.
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

# Install
if $IS_WINDOWS; then
  INSTALL_DIR="$HOME/bin"
  mkdir -p "$INSTALL_DIR"
  mv -f "$BIN_PATH" "$INSTALL_DIR/$BINARY_NAME.exe"
else
  INSTALL_DIR="/usr/local/bin"
  sudo mv -f "$BIN_PATH" "$INSTALL_DIR/$BINARY_NAME"
  sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
fi

echo "Installed $BINARY_NAME to $INSTALL_DIR."

# # Optional: Set up environment variables
# read -p "Do you want to set up environment variables for $PROJECT_DESC? (y/N): " SETUP_ENV
# if [[ "$SETUP_ENV" =~ ^[Yy]$ ]]; then
#   read -p "API endpoint (or leave blank for default): " ENDPOINT
#   read -p "API key (or leave blank): " API_KEY
#   read -p "Model (or leave blank): " MODEL

#   # Detect shell
#   CURRENT_SHELL=$(basename "$SHELL")
#   case "$CURRENT_SHELL" in
#     zsh) PROFILE_FILE=~/.zshrc ;;
#     bash) PROFILE_FILE=~/.bashrc ;;
#     fish) PROFILE_FILE=~/.config/fish/config.fish ;;
#     *) PROFILE_FILE=~/.profile ;;
#   esac
#   touch "$PROFILE_FILE"
#   if [[ "$CURRENT_SHELL" == "fish" ]]; then
#     [[ -n "$ENDPOINT" ]] && echo "set -x ${BINARY_NAME^^}_API_BASE \"$ENDPOINT\"" >> "$PROFILE_FILE"
#     [[ -n "$API_KEY" ]] && echo "set -x ${BINARY_NAME^^}_API_KEY \"$API_KEY\"" >> "$PROFILE_FILE"
#     [[ -n "$MODEL" ]] && echo "set -x ${BINARY_NAME^^}_MODEL \"$MODEL\"" >> "$PROFILE_FILE"
#   else
#     [[ -n "$ENDPOINT" ]] && echo "export ${BINARY_NAME^^}_API_BASE=\"$ENDPOINT\"" >> "$PROFILE_FILE"
#     [[ -n "$API_KEY" ]] && echo "export ${BINARY_NAME^^}_API_KEY=\"$API_KEY\"" >> "$PROFILE_FILE"
#     [[ -n "$MODEL" ]] && echo "export ${BINARY_NAME^^}_MODEL=\"$MODEL\"" >> "$PROFILE_FILE"
#   fi
#   echo "Environment variables set in $PROFILE_FILE. Run 'source $PROFILE_FILE' to activate."
# fi

echo "Done! Run '$BINARY_NAME --version' to verify installation."
