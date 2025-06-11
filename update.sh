#!/bin/bash

# RustyFace Update Script
# This script updates RustyFace to the latest version from GitHub

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

# Function to get current installed version
get_current_version() {
    if command -v rustyface >/dev/null 2>&1; then
        rustyface --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Function to compare versions
version_gt() {
    # Remove 'v' prefix if present
    local ver1=$(echo "$1" | sed 's/^v//')
    local ver2=$(echo "$2" | sed 's/^v//')
    
    # Use sort -V for version comparison
    test "$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)" != "$ver1"
}

# Function to download and install binary
update_binary() {
    local platform=$1
    local version=$2
    local binary_suffix=""
    
    if [[ "$platform" == *"windows"* ]]; then
        binary_suffix=".exe"
    fi
    
    local download_url="https://github.com/${REPO}/releases/download/${version}/rustyface_${platform}"
    local temp_file="/tmp/rustyface_update${binary_suffix}"
    
    print_message $BLUE "Downloading RustyFace ${version} for ${platform}..."
    
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L -o "$temp_file" "$download_url"; then
            print_message $RED "Error: Failed to download the binary from $download_url"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$temp_file" "$download_url"; then
            print_message $RED "Error: Failed to download the binary from $download_url"
            exit 1
        fi
    else
        print_message $RED "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    if [ ! -f "$temp_file" ]; then
        print_message $RED "Error: Downloaded file not found."
        exit 1
    fi
    
    # Verify the download is a valid binary (basic check)
    if [ ! -s "$temp_file" ]; then
        print_message $RED "Error: Downloaded file is empty."
        rm -f "$temp_file"
        exit 1
    fi
    
    # Find current installation location
    local current_location=""
    if command -v rustyface >/dev/null 2>&1; then
        current_location=$(command -v rustyface)
        print_message $BLUE "Found existing installation at: $current_location"
    else
        current_location="$INSTALL_DIR/$BINARY_NAME"
        mkdir -p "$INSTALL_DIR"
        print_message $BLUE "Will install to: $current_location"
    fi
    
    # Backup current version
    if [ -f "$current_location" ]; then
        cp "$current_location" "${current_location}.backup.$(date +%Y%m%d_%H%M%S)"
        print_message $BLUE "Backed up current version"
    fi
    
    # Replace with new version
    mv "$temp_file" "$current_location"
    chmod +x "$current_location"
    
    print_message $GREEN "RustyFace has been updated successfully!"
}

# Function to handle Cargo installation
handle_cargo_update() {
    print_message $YELLOW "RustyFace appears to be installed via Cargo."
    print_message $BLUE "To update the Cargo version, you can run:"
    print_message $BLUE "  cargo install rustyface --force"
    print_message $BLUE ""
    read -p "Would you like to switch to binary installation instead? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0  # Continue with binary installation
    else
        print_message $BLUE "Update cancelled. Use cargo to update your installation."
        exit 0
    fi
}

# Main update process
main() {
    print_message $BLUE "🔄 RustyFace Update Script"
    print_message $BLUE "=========================="
    
    # Check if curl or wget is available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        print_message $RED "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Check if RustyFace is installed
    local current_version=$(get_current_version)
    if [ "$current_version" = "not_installed" ]; then
        print_message $YELLOW "RustyFace is not installed on your system."
        print_message $BLUE "Please run the setup script to install RustyFace:"
        print_message $BLUE "  ./setup.sh"
        exit 1
    fi
    
    print_message $GREEN "Current version: $current_version"
    
    # Check if installed via Cargo
    if command -v cargo >/dev/null 2>&1; then
        if cargo install --list 2>/dev/null | grep -q "^rustyface"; then
            handle_cargo_update
        fi
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
    local latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        print_message $RED "Error: Could not fetch the latest version from GitHub"
        print_message $RED "Please check your internet connection and try again."
        exit 1
    fi
    
    print_message $GREEN "Latest version: $latest_version"
    
    # Compare versions
    if [ "$current_version" = "$latest_version" ]; then
        print_message $GREEN "✅ You already have the latest version of RustyFace!"
        exit 0
    elif [ "$current_version" = "unknown" ] || version_gt "$latest_version" "$current_version"; then
        print_message $YELLOW "A newer version is available: $current_version → $latest_version"
        read -p "Do you want to update? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_message $BLUE "Update cancelled."
            exit 0
        fi
    else
        print_message $BLUE "Your version ($current_version) is newer than the latest release ($latest_version)"
        read -p "Do you want to downgrade to the latest release? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $BLUE "Update cancelled."
            exit 0
        fi
    fi
    
    # Perform update
    update_binary "$platform" "$latest_version"
    
    # Verify update
    local new_version=$(get_current_version)
    if [ "$new_version" = "$latest_version" ]; then
        print_message $GREEN "✅ Update completed successfully!"
        print_message $GREEN "RustyFace is now at version $new_version"
    else
        print_message $YELLOW "⚠️  Update completed, but version verification failed."
        print_message $YELLOW "Expected: $latest_version, Got: $new_version"
        print_message $BLUE "This might be normal if the version output format changed."
    fi
    
    print_message $BLUE "You can verify the installation by running: rustyface --help"
}

# Run main function
main "$@"
