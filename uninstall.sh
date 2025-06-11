#!/bin/bash

# RustyFace Uninstall Script
# This script removes RustyFace from your system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BINARY_NAME="rustyface"
INSTALL_DIR="$HOME/.local/bin"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to remove binary
remove_binary() {
    local binary_path="$INSTALL_DIR/$BINARY_NAME"
    
    if [ -f "$binary_path" ]; then
        rm -f "$binary_path"
        print_message $GREEN "Removed RustyFace binary from $binary_path"
        return 0
    else
        print_message $YELLOW "RustyFace binary not found in $binary_path"
        return 1
    fi
}

# Function to find and remove from system PATH
remove_from_system() {
    local found=false
    
    # Check common system locations
    local system_paths=(
        "/usr/local/bin/$BINARY_NAME"
        "/usr/bin/$BINARY_NAME"
        "/opt/local/bin/$BINARY_NAME"
    )
    
    for path in "${system_paths[@]}"; do
        if [ -f "$path" ]; then
            print_message $YELLOW "Found RustyFace at $path"
            if [ -w "$(dirname "$path")" ]; then
                rm -f "$path"
                print_message $GREEN "Removed RustyFace from $path"
                found=true
            else
                print_message $RED "Permission denied to remove $path. Please run with sudo:"
                print_message $RED "  sudo rm -f $path"
                found=true
            fi
        fi
    done
    
    return $found
}

# Function to remove PATH entries from shell RC files
clean_path_entries() {
    local shell_files=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    local cleaned=false
    
    for file in "${shell_files[@]}"; do
        if [ -f "$file" ]; then
            # Create a backup
            cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Remove RustyFace-related PATH entries
            if grep -q "Added by RustyFace installer" "$file" 2>/dev/null; then
                # Remove the comment line and the export line
                sed -i '/# Added by RustyFace installer/d' "$file" 2>/dev/null || true
                sed -i "\|export PATH=.*$INSTALL_DIR|d" "$file" 2>/dev/null || true
                print_message $GREEN "Cleaned PATH entries from $file"
                cleaned=true
            fi
        fi
    done
    
    if $cleaned; then
        print_message $YELLOW "Shell configuration files have been backed up with timestamp suffix"
        print_message $YELLOW "Please restart your terminal or reload your shell configuration"
    fi
    
    return $cleaned
}

# Function to check if RustyFace was installed via Cargo
check_cargo_installation() {
    if command -v cargo >/dev/null 2>&1; then
        if cargo install --list 2>/dev/null | grep -q "^rustyface"; then
            print_message $YELLOW "RustyFace appears to be installed via Cargo"
            print_message $BLUE "To uninstall the Cargo version, run:"
            print_message $BLUE "  cargo uninstall rustyface"
            return 0
        fi
    fi
    return 1
}

# Main uninstall process
main() {
    print_message $BLUE "🗑️  RustyFace Uninstaller"
    print_message $BLUE "========================"
    
    # Check if RustyFace is installed
    if ! command -v rustyface >/dev/null 2>&1; then
        print_message $YELLOW "RustyFace is not found in your PATH"
    else
        local current_version=$(rustyface --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        print_message $BLUE "Found RustyFace version: $current_version"
        print_message $BLUE "Location: $(command -v rustyface)"
    fi
    
    # Confirm uninstallation
    read -p "Are you sure you want to uninstall RustyFace? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $BLUE "Uninstallation cancelled."
        exit 0
    fi
    
    local removed_something=false
    
    # Remove from install directory
    if remove_binary; then
        removed_something=true
    fi
    
    # Check and remove from system paths
    if remove_from_system; then
        removed_something=true
    fi
    
    # Clean PATH entries from shell RC files
    if clean_path_entries; then
        removed_something=true
    fi
    
    # Check for Cargo installation
    check_cargo_installation
    
    if $removed_something; then
        print_message $GREEN "✅ RustyFace has been uninstalled successfully!"
        print_message $BLUE "You may need to restart your terminal for PATH changes to take effect."
    else
        print_message $YELLOW "No RustyFace installation found to remove."
    fi
    
    # Final verification
    if command -v rustyface >/dev/null 2>&1; then
        print_message $YELLOW "Note: RustyFace is still available in your PATH at:"
        print_message $YELLOW "  $(command -v rustyface)"
        print_message $YELLOW "This might be a Cargo installation or a system-wide installation."
    else
        print_message $GREEN "RustyFace is no longer available in your PATH."
    fi
}

# Run main function
main "$@"
