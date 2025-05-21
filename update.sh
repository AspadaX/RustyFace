#!/bin/bash

set -eo pipefail

echo "RustyFace Update Script"
echo "======================="

# Check if rustyface is installed
if ! command -v rustyface &> /dev/null; then
    echo "Error: RustyFace is not installed. Please run setup.sh instead."
    exit 1
fi

CURRENT_VERSION=$(rustyface --version 2>/dev/null || echo "unknown")
echo "Current version: $CURRENT_VERSION"

# Determine OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Check if running in Windows
IS_WINDOWS=false
if [[ "$OS" == *"windows"* || "$OS" == *"mingw"* || "$OS" == *"msys"* || "$OS" == *"cygwin"* ]]; then
  IS_WINDOWS=true
  OS="windows"
fi

# Map architecture to standard format
case $ARCH in
  x86_64) ARCH="x86_64" ;;
  arm64|aarch64) ARCH="aarch64" ;;
  armv7l) ARCH="arm" ;;
  i686) ARCH="i686" ;;
  *) echo "Warning: Unsupported architecture: $ARCH. Attempting to continue." ;;
esac

# Function to update from cargo
update_from_cargo() {
  echo "Updating RustyFace from cargo..."
  
  if ! command -v cargo &> /dev/null; then
    echo "Error: Cargo not found. Please install Rust to update via cargo."
    return 1
  fi
  
  cargo install rustyface --force
  
  if [ $? -eq 0 ]; then
    NEW_VERSION=$(rustyface --version)
    echo "Successfully updated RustyFace to version $NEW_VERSION"
  else
    echo "Failed to update RustyFace via cargo."
    return 1
  fi
}

# Function to update from binary
update_from_binary() {
  echo "Updating RustyFace from prebuilt binary..."
  
  # Determine filename for this platform
  if $IS_WINDOWS; then
    FILENAME="rustyface_windows_${ARCH}.zip"
  else
    case $OS in
      linux*)
        FILENAME="rustyface_linux_${ARCH}.tar.gz"
        ;;
      darwin*)
        FILENAME="rustyface_macos_${ARCH}.tar.gz"
        ;;
      *)
        echo "No prebuilt binary for your platform. Updating from cargo..."
        update_from_cargo
        return
        ;;
    esac
  fi
  
  # GitHub repository and latest release URL
  REPO="AspadaX/RustyFace"
  RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
  
  # Get latest version information
  echo "Checking for latest version..."
  RELEASE_INFO=$(curl -s $RELEASE_URL)
  LATEST_VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"//;s/"//')
  
  if [[ -z "$LATEST_VERSION" ]]; then
    echo "Could not determine latest version. Falling back to cargo update..."
    update_from_cargo
    return
  fi
  
  echo "Latest version: $LATEST_VERSION"
  
  # Compare versions and exit if already up to date
  if [[ "$CURRENT_VERSION" == *"$LATEST_VERSION"* ]]; then
    echo "You are already running the latest version ($LATEST_VERSION)."
    exit 0
  fi
  
  # Get download URL
  DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "https://.*/$FILENAME" | head -1)
  if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Error: Could not find download URL for $FILENAME in the latest release."
    echo "Falling back to cargo update..."
    update_from_cargo
    return
  fi
  
  # Create temporary directory
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT
  
  # Download binary
  echo "Downloading $FILENAME..."
  curl -L -o "$TMPDIR/$FILENAME" "$DOWNLOAD_URL"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download the binary."
    echo "Falling back to cargo update..."
    update_from_cargo
    return
  fi
  
  # Extract and install
  if $IS_WINDOWS; then
    echo "Extracting Windows binary..."
    if command -v unzip >/dev/null 2>&1; then
      unzip -o "$TMPDIR/$FILENAME" -d "$TMPDIR"
    else
      echo "Error: unzip command not found. Please install unzip to continue."
      update_from_cargo
      return
    fi
    
    # Find binary
    BIN_PATH=$(find "$TMPDIR" -name "rustyface*.exe" -type f -print -quit)
    INSTALL_DIR="$HOME/bin"
    
    if [[ -z $BIN_PATH ]]; then
      echo "Error: Could not find binary in the package"
      update_from_cargo
      return
    fi
    
    echo "Installing rustyface to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR" 2>/dev/null
    cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface.exe"
  else
    echo "Extracting binary..."
    tar xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"
    
    # Find binary
    BIN_PATH=$(find "$TMPDIR" -name "rustyface*" -type f -print -quit)
    
    if [[ -z $BIN_PATH ]]; then
      echo "Error: Could not find binary in the package"
      update_from_cargo
      return
    fi
    
    # Find the current installation path
    CURRENT_PATH=$(which rustyface)
    INSTALL_DIR=$(dirname "$CURRENT_PATH")
    
    if [[ ! -w "$INSTALL_DIR" ]]; then
      echo "Installing to $INSTALL_DIR requires sudo access."
      sudo cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface"
      sudo chmod +x "$INSTALL_DIR/rustyface"
    else
      cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface"
      chmod +x "$INSTALL_DIR/rustyface"
    fi
  fi
  
  # Verify installation
  if command -v rustyface &> /dev/null; then
    NEW_VERSION=$(rustyface --version)
    echo "Successfully updated RustyFace to version $NEW_VERSION"
  else
    echo "Update seems to have failed. The 'rustyface' command is not available."
    return 1
  fi
}

# Main logic
echo "RustyFace can be updated from cargo or from a prebuilt binary (if available)."
echo "1) Update from cargo (requires Rust toolchain)"
echo "2) Update from prebuilt binary (if available for your platform)"
echo "Please select an option (1/2):"

read -r update_option

case $update_option in
  1)
    update_from_cargo
    ;;
  2)
    update_from_binary
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac

echo ""
echo "You can use RustyFace with the following command:"
echo "rustyface --repository <repo_id> --tasks <num_tasks>"
echo ""
echo "Example: rustyface --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4"