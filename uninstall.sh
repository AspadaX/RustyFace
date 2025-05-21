#!/bin/bash

set -eo pipefail

echo "RustyFace Uninstall Script"
echo "=========================="

# Determine OS and architecture
OS=$(uname -s 2>/dev/null || echo "Windows_NT")
OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')

# Check if running in Windows
IS_WINDOWS=false
if [[ "$OS" == *"windows"* || "$OS" == *"mingw"* || "$OS" == *"msys"* || "$OS" == *"cygwin"* ]]; then
  IS_WINDOWS=true
  OS="windows"
fi

# Function to uninstall binary
uninstall_binary() {
  if $IS_WINDOWS; then
    # For Windows
    if [[ -f "$HOME/bin/rustyface.exe" ]]; then
      echo "Removing rustyface.exe from $HOME/bin..."
      rm -f "$HOME/bin/rustyface.exe"
      echo "Binary removed."
    else
      echo "Cannot find rustyface.exe in the standard installation location."
      echo "If you installed it elsewhere, please remove it manually."
    fi
  else
    # For Unix-like systems
    if command -v rustyface &> /dev/null; then
      BINARY_PATH=$(which rustyface)
      echo "Found RustyFace at: $BINARY_PATH"
      echo "Removing..."
      
      if [[ -w "$(dirname "$BINARY_PATH")" ]]; then
        rm -f "$BINARY_PATH"
      else
        echo "Uninstallation requires sudo privileges."
        sudo rm -f "$BINARY_PATH"
      fi
      
      echo "Binary removed."
    else
      echo "Cannot find rustyface in your PATH."
      
      # Check common installation locations
      COMMON_LOCATIONS=(
        "/usr/local/bin/rustyface"
        "/usr/bin/rustyface"
        "$HOME/.cargo/bin/rustyface"
      )
      
      for location in "${COMMON_LOCATIONS[@]}"; do
        if [[ -f "$location" ]]; then
          echo "Found RustyFace at: $location"
          echo "Removing..."
          
          if [[ -w "$(dirname "$location")" ]]; then
            rm -f "$location"
          else
            echo "Uninstallation requires sudo privileges."
            sudo rm -f "$location"
          fi
          
          echo "Binary removed."
          return 0
        fi
      done
      
      echo "Could not find RustyFace binary installed on this system."
    fi
  fi
}

# Function to uninstall from cargo if installed that way
uninstall_cargo() {
  if command -v cargo &> /dev/null; then
    echo "Checking if RustyFace was installed via cargo..."
    if cargo install --list | grep -q "rustyface"; then
      echo "Removing RustyFace via cargo..."
      cargo uninstall rustyface
      echo "RustyFace has been uninstalled from cargo."
    else
      echo "RustyFace does not appear to be installed via cargo."
    fi
  fi
}

# Main uninstall logic
echo "This script will remove RustyFace from your system."
echo "Do you want to continue? (y/n)"
read -r confirmation

if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
  echo "Uninstallation cancelled."
  exit 0
fi

uninstall_binary
uninstall_cargo

echo ""
echo "RustyFace has been uninstalled from your system."
echo "Any downloaded repositories would still remain in your local directories."