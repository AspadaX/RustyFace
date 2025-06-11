#!/bin/bash

# RustyFace Setup Script
# This script downloads and installs the latest RustyFace binary from GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="AspadaX/RustyFace"
BINARY_NAME="rustyface"
INSTALL_DIR="$HOME/.local/bin"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to detect OS and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        linux)
            case "$arch" in
                x86_64) echo "linux_x86_64" ;;
                aarch64|arm64) echo "linux_aarch64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        darwin)
            case "$arch" in
                x86_64) echo "darwin_x86_64" ;;
                arm64) echo "darwin_aarch64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        mingw*|msys*|cygwin*)
            case "$arch" in
                x86_64) echo "windows_x86_64.exe" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Function to get the latest release version
get_latest_version() {
    curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to download and install binary
install_binary() {
    local platform=$1
    local version=$2
    local binary_suffix=""
    
    if [[ "$platform" == *"windows"* ]]; then
        binary_suffix=".exe"
    fi
    
    local download_url="https://github.com/${REPO}/releases/download/${version}/rustyface_${platform}"
    local temp_file="/tmp/rustyface${binary_suffix}"
    
    print_message $BLUE "Downloading RustyFace ${version} for ${platform}..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    else
        print_message $RED "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    if [ ! -f "$temp_file" ]; then
        print_message $RED "Error: Failed to download the binary."
        exit 1
    fi
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Move binary to install directory
    mv "$temp_file" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    print_message $GREEN "RustyFace has been installed to $INSTALL_DIR/$BINARY_NAME"
}

# Function to update PATH
update_path() {
    local shell_rc=""
    
    # Detect shell and set appropriate RC file
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
        [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if install directory is already in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "" >> "$shell_rc"
        echo "# Added by RustyFace installer" >> "$shell_rc"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$shell_rc"
        print_message $YELLOW "Added $INSTALL_DIR to PATH in $shell_rc"
        print_message $YELLOW "Please restart your terminal or run: source $shell_rc"
    else
        print_message $GREEN "$INSTALL_DIR is already in your PATH"
    fi
}

# Main installation process
main() {
    print_message $BLUE "🦀 RustyFace Installation Script"
    print_message $BLUE "================================="
    
    # Check if git is available for version checking
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        print_message $RED "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Detect platform
    local platform=$(detect_platform)
    if [ "$platform" = "unsupported" ]; then
        print_message $RED "Error: Unsupported platform $(uname -s)/$(uname -m)"
        print_message $RED "Supported platforms: Linux (x86_64, aarch64), macOS (x86_64, arm64), Windows (x86_64)"
        exit 1
    fi
    
    print_message $GREEN "Detected platform: $platform"
    
    # Get latest version
    local version=$(get_latest_version)
    if [ -z "$version" ]; then
        print_message $RED "Error: Could not fetch the latest version from GitHub"
        exit 1
    fi
    
    print_message $GREEN "Latest version: $version"
    
    # Check if already installed
    if command -v rustyface >/dev/null 2>&1; then
        local current_version=$(rustyface --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        print_message $YELLOW "RustyFace is already installed (version: $current_version)"
        read -p "Do you want to reinstall/update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $BLUE "Installation cancelled."
            exit 0
        fi
    fi
    
    # Install binary
    install_binary "$platform" "$version"
    
    # Update PATH
    update_path
    
    print_message $GREEN "✅ Installation completed successfully!"
    print_message $BLUE "You can now use RustyFace by running: rustyface --help"
    print_message $BLUE "If the command is not found, please restart your terminal or run:"
    print_message $BLUE "  export PATH=\"\$PATH:$INSTALL_DIR\""
}

# Run main function
main "$@"
