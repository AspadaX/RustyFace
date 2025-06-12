#!/bin/bash

# =====================
# RustyFace Uninstall Script (Template)
# =====================
# This script uninstalls a GitHub CLI tool installed by setup.sh.
# To reuse for other projects, change the variables in the CONFIGURATION section.

set -eo pipefail

# ------------- CONFIGURATION -------------
REPO="AspadaX/RustyFace"           # GitHub repo (e.g. owner/repo)
BINARY_NAME="rustyface"            # Name of the binary (no extension)
PROJECT_DESC="RustyFace CLI tool"  # Description for prompts
# ------------- END CONFIG ---------------

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
IS_WINDOWS=false
if [[ "$OS" == *"mingw"* || "$OS" == *"msys"* || "$OS" == *"cygwin"* ]]; then
  IS_WINDOWS=true
  OS="windows"
fi

# Remove binary
if $IS_WINDOWS; then
  INSTALL_DIR="$HOME/bin"
  BIN_PATH="$INSTALL_DIR/$BINARY_NAME.exe"
else
  INSTALL_DIR="/usr/local/bin"
  BIN_PATH="$INSTALL_DIR/$BINARY_NAME"
fi

if [[ -f "$BIN_PATH" ]]; then
  echo "Removing $BIN_PATH..."
  if $IS_WINDOWS; then
    rm -f "$BIN_PATH"
  else
    sudo rm -f "$BIN_PATH"
  fi
  echo "$BINARY_NAME removed from $INSTALL_DIR."
else
  echo "$BINARY_NAME not found in $INSTALL_DIR."
fi

# # Optionally remove environment variables
# read -p "Do you want to remove environment variables for $PROJECT_DESC from your shell profile? (y/N): " REMOVE_ENV
# if [[ "$REMOVE_ENV" =~ ^[Yy]$ ]]; then
#   # Detect shell
#   CURRENT_SHELL=$(basename "$SHELL")
#   case "$CURRENT_SHELL" in
#     zsh) PROFILE_FILE=~/.zshrc ;;
#     bash) PROFILE_FILE=~/.bashrc ;;
#     fish) PROFILE_FILE=~/.config/fish/config.fish ;;
#     *) PROFILE_FILE=~/.profile ;;
#   esac
#   if [[ -f "$PROFILE_FILE" ]]; then
#     echo "Cleaning environment variables from $PROFILE_FILE..."
#     if [[ "$CURRENT_SHELL" == "fish" ]]; then
#       sed -i.bak "/set -x ${BINARY_NAME^^}_API_BASE/d" "$PROFILE_FILE"
#       sed -i.bak "/set -x ${BINARY_NAME^^}_API_KEY/d" "$PROFILE_FILE"
#       sed -i.bak "/set -x ${BINARY_NAME^^}_MODEL/d" "$PROFILE_FILE"
#     else
#       sed -i.bak "/export ${BINARY_NAME^^}_API_BASE=/d" "$PROFILE_FILE"
#       sed -i.bak "/export ${BINARY_NAME^^}_API_KEY=/d" "$PROFILE_FILE"
#       sed -i.bak "/export ${BINARY_NAME^^}_MODEL=/d" "$PROFILE_FILE"
#     fi
#     echo "Environment variable lines removed from $PROFILE_FILE."
#   else
#     echo "Profile file $PROFILE_FILE not found, nothing to clean."
#   fi
# fi

echo "Uninstallation complete."
