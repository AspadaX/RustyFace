#!/bin/bash

set -eo pipefail

echo "RustyFace Installation Script"
echo "============================="

# Function to detect system information
detect_system() {
  OS=$(uname -s 2>/dev/null || echo "Windows_NT")
  OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m 2>/dev/null || echo "x86_64")

  # Check if Windows
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

  # Determine system combination
  case $OS in
    linux*)
      PLATFORM="unknown-linux"
      if ldd --version 2>&1 | grep -iq musl || [[ -n $(find /lib -name 'ld-musl-*' -print -quit) ]]; then
        PLATFORM="unknown-linux-musl"
      else
        PLATFORM="unknown-linux-gnu"
      fi
      ;;
    darwin*)
      PLATFORM="apple-darwin"
      ;;
    freebsd*)
      PLATFORM="unknown-freebsd"
      ;;
    windows*)
      PLATFORM="pc-windows-msvc"
      ;;
    *)
      echo "Unsupported operating system: $OS"
      exit 1
      ;;
  esac

  TARGET="${ARCH}-${PLATFORM}"
  echo "Detected system: $TARGET"
}

# Function to check for Rust toolchain
check_rust() {
  if ! command -v rustc &> /dev/null; then
    echo "Rust not found. Would you like to install it? (y/n)"
    read -r install_rust
    if [[ "$install_rust" == "y" || "$install_rust" == "Y" ]]; then
      echo "Installing Rust..."
      if $IS_WINDOWS; then
        echo "Please download and run the Rust installer from https://win.rustup.rs/"
        echo "After installation completes, please run this script again."
        exit 0
      else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source "$HOME/.cargo/env"
      fi
    else
      echo "Rust is required to install RustyFace from source."
      echo "You can either:"
      echo "1. Run this script again and choose to install Rust."
      echo "2. Download a pre-built binary from the GitHub releases page:"
      echo "   https://github.com/AspadaX/RustyFace/releases"
      exit 1
    fi
  fi
}

# Function to install from source
install_from_source() {
  echo "Installing RustyFace from source..."
  
  # Check if we're already in the RustyFace directory
  if [[ -f "Cargo.toml" && -d "src" && -f "src/main.rs" ]]; then
    echo "Building RustyFace in current directory..."
    cargo install --path .
  else
    echo "Would you like to clone the repository? (y/n)"
    read -r clone_repo
    if [[ "$clone_repo" == "y" || "$clone_repo" == "Y" ]]; then
      if ! command -v git &> /dev/null; then
        echo "Error: git is required to clone the repository."
        exit 1
      fi
      
      echo "Cloning RustyFace repository..."
      git clone https://github.com/AspadaX/RustyFace.git
      cd RustyFace
      cargo install --path .
      cd ..
    else
      echo "Installing from crates.io..."
      cargo install rustyface
    fi
  fi
}

# Function to install from prebuilt binary
install_from_binary() {
  echo "Installing RustyFace from prebuilt binary..."
  
  # GitHub repository and latest release URL
  REPO="AspadaX/RustyFace"
  RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
  
  echo "Fetching latest release information..."
  RELEASE_INFO=$(curl -s -f $RELEASE_URL)
  if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch release information from GitHub."
    echo "Falling back to installation from source..."
    install_from_source
    return
  fi
  
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
        echo "No prebuilt binary for your platform. Installing from source..."
        install_from_source
        return
        ;;
    esac
  fi
  
  # Get download URL
  DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "https://.*/$FILENAME" | head -1)
  if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Error: Could not find download URL for $FILENAME in the latest release."
    echo "Falling back to installation from source..."
    install_from_source
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
    echo "Falling back to installation from source..."
    install_from_source
    return
  fi
  
  # Extract and install
  if $IS_WINDOWS; then
    echo "Extracting Windows binary..."
    if command -v unzip >/dev/null 2>&1; then
      unzip -o "$TMPDIR/$FILENAME" -d "$TMPDIR"
    else
      echo "Error: unzip command not found. Please install unzip to continue."
      return 1
    fi
    
    # Find binary
    BIN_PATH=$(find "$TMPDIR" -name "rustyface*.exe" -type f -print -quit)
    INSTALL_DIR="$HOME/bin"
    mkdir -p "$INSTALL_DIR" 2>/dev/null
    
    echo "Installing rustyface to $INSTALL_DIR..."
    cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface.exe"
    
    # Add to PATH if not already there
    if [[ ";$PATH;" != *";$INSTALL_DIR;"* ]]; then
      echo "Adding $INSTALL_DIR to PATH in your profile..."
      echo "You may need to restart your terminal or run 'set PATH=%PATH%;$INSTALL_DIR' manually."
      if [[ -f "$HOME/.profile" ]]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.profile"
      fi
    fi
  else
    echo "Extracting binary..."
    tar xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"
    
    # Find binary
    BIN_PATH=$(find "$TMPDIR" -name "rustyface*" -type f -print -quit)
    if [[ -z $BIN_PATH ]]; then
      echo "Error: Could not find binary in the package"
      return 1
    fi
    
    INSTALL_DIR="/usr/local/bin"
    if [[ ! -w "$INSTALL_DIR" ]]; then
      echo "Installing to $INSTALL_DIR requires sudo access."
      sudo cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface"
      sudo chmod +x "$INSTALL_DIR/rustyface"
    else
      cp -f "$BIN_PATH" "$INSTALL_DIR/rustyface"
      chmod +x "$INSTALL_DIR/rustyface"
    fi
  fi
  
  echo "RustyFace has been installed successfully!"
}

# Main installation logic
main() {
  detect_system
  
  echo "RustyFace can be installed from source or from a prebuilt binary (if available)."
  echo "1) Install from source (requires Rust toolchain)"
  echo "2) Install from prebuilt binary (if available for your platform)"
  echo "Please select an option (1/2):"
  
  read -r install_option
  
  case $install_option in
    1)
      check_rust
      install_from_source
      ;;
    2)
      install_from_binary
      ;;
    *)
      echo "Invalid option. Exiting."
      exit 1
      ;;
  esac
  
  echo ""
  echo "RustyFace installation completed!"
  echo "You can now use RustyFace with the following command:"
  echo "rustyface --repository <repo_id> --tasks <num_tasks>"
  echo ""
  echo "Example: rustyface --repository sentence-transformers/all-MiniLM-L6-v2 --tasks 4"
}

main