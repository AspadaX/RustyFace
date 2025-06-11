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

# Function to check shell compatibility
check_shell_compatibility() {
    # Check if we're running in a POSIX-compatible shell
    if [ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ]; then
        # Test some bash/zsh specific features we use
        if ! (echo "test" | grep -q "test") 2>/dev/null; then
            print_message $YELLOW "Warning: Your shell may have limited compatibility"
            print_message $YELLOW "This script is optimized for bash and zsh"
        fi
    fi
    
    # Check for required commands
    local missing_commands=""
    for cmd in curl wget grep sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            if [ "$cmd" = "curl" ] || [ "$cmd" = "wget" ]; then
                continue  # We only need one of curl or wget
            else
                missing_commands="$missing_commands $cmd"
            fi
        fi
    done
    
    if [ -n "$missing_commands" ]; then
        print_message $RED "Error: Missing required commands:$missing_commands"
        print_message $RED "Please install these commands and try again"
        exit 1
    fi
}

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

# Function to detect shell and get appropriate RC file
detect_shell() {
    local current_shell=""
    local shell_rc=""
    
    # Method 1: Check the user's default shell from SHELL environment variable first
    # This is more reliable than checking version variables when script is run via curl|bash
    case "$SHELL" in
        */zsh)
            current_shell="zsh"
            shell_rc="$HOME/.zshrc"
            ;;
        */bash)
            current_shell="bash"
            # On macOS, prefer .bash_profile over .bashrc
            if [[ "$OSTYPE" == "darwin"* ]]; then
                shell_rc="$HOME/.bash_profile"
            else
                shell_rc="$HOME/.bashrc"
                [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
            fi
            ;;
        */fish)
            current_shell="fish"
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        */tcsh|*/csh)
            current_shell="csh"
            shell_rc="$HOME/.cshrc"
            ;;
        */ksh)
            current_shell="ksh"
            shell_rc="$HOME/.kshrc"
            ;;
        *)
            # Method 2: Fallback to checking shell-specific environment variables
            if [ -n "$ZSH_VERSION" ]; then
                current_shell="zsh"
                shell_rc="$HOME/.zshrc"
            elif [ -n "$BASH_VERSION" ]; then
                current_shell="bash"
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    shell_rc="$HOME/.bash_profile"
                else
                    shell_rc="$HOME/.bashrc"
                    [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
                fi
            else
                # Method 3: Try to detect from parent process
                local parent_shell=""
                if command -v ps >/dev/null 2>&1; then
                    parent_shell=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ' || echo "")
                fi
                
                case "$parent_shell" in
                    *zsh*)
                        current_shell="zsh"
                        shell_rc="$HOME/.zshrc"
                        ;;
                    *bash*)
                        current_shell="bash"
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            shell_rc="$HOME/.bash_profile"
                        else
                            shell_rc="$HOME/.bashrc"
                            [ -f "$HOME/.bash_profile" ] && shell_rc="$HOME/.bash_profile"
                        fi
                        ;;
                    *fish*)
                        current_shell="fish"
                        shell_rc="$HOME/.config/fish/config.fish"
                        ;;
                    *)
                        # Method 4: Default fallback - check which shell RC files exist
                        if [ -f "$HOME/.zshrc" ]; then
                            current_shell="zsh"
                            shell_rc="$HOME/.zshrc"
                        elif [ -f "$HOME/.bash_profile" ] && [[ "$OSTYPE" == "darwin"* ]]; then
                            current_shell="bash"
                            shell_rc="$HOME/.bash_profile"
                        elif [ -f "$HOME/.bashrc" ]; then
                            current_shell="bash"
                            shell_rc="$HOME/.bashrc"
                        elif [ -f "$HOME/.config/fish/config.fish" ]; then
                            current_shell="fish"
                            shell_rc="$HOME/.config/fish/config.fish"
                        else
                            current_shell="unknown"
                            shell_rc="$HOME/.profile"
                        fi
                        ;;
                esac
            fi
            ;;
    esac
    
    echo "$current_shell:$shell_rc"
}

# Function to update PATH
update_path() {
    local shell_info=$(detect_shell)
    local current_shell=$(echo "$shell_info" | cut -d':' -f1)
    local shell_rc=$(echo "$shell_info" | cut -d':' -f2)
    
    print_message $BLUE "Detected shell: $current_shell"
    print_message $BLUE "Using configuration file: $shell_rc"
    
    # Debug information for troubleshooting
    if [ "$current_shell" = "unknown" ] || [ -n "$DEBUG_SHELL" ]; then
        print_message $YELLOW "Debug info:"
        print_message $YELLOW "  \$0 = $0"
        print_message $YELLOW "  \$SHELL = $SHELL"
        print_message $YELLOW "  \$ZSH_VERSION = $ZSH_VERSION"
        print_message $YELLOW "  \$BASH_VERSION = $BASH_VERSION"
        print_message $YELLOW "  \$PPID = $PPID"
        print_message $YELLOW "  Parent process: $(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ' || echo 'unknown')"
        print_message $YELLOW "  Current process: $(ps -p $$ -o comm= 2>/dev/null | tr -d ' ' || echo 'unknown')"
    fi
    
    # Check if install directory is already in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        # Create the directory for the config file if it doesn't exist (for fish shell)
        if [ "$current_shell" = "fish" ]; then
            mkdir -p "$(dirname "$shell_rc")"
        fi
        
        # Add PATH entry based on shell type
        if [ "$current_shell" = "fish" ]; then
            echo "" >> "$shell_rc"
            echo "# Added by RustyFace installer" >> "$shell_rc"
            echo "fish_add_path $INSTALL_DIR" >> "$shell_rc"
        elif [ "$current_shell" = "csh" ]; then
            echo "" >> "$shell_rc"
            echo "# Added by RustyFace installer" >> "$shell_rc"
            echo "setenv PATH \"\$PATH:$INSTALL_DIR\"" >> "$shell_rc"
        else
            # For bash, zsh, ksh, and others using POSIX syntax
            echo "" >> "$shell_rc"
            echo "# Added by RustyFace installer" >> "$shell_rc"
            echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$shell_rc"
        fi
        
        print_message $YELLOW "Added $INSTALL_DIR to PATH in $shell_rc"
        
        # Provide shell-specific reload instructions
        case "$current_shell" in
            fish)
                print_message $YELLOW "Please restart your terminal or run: source $shell_rc"
                print_message $BLUE "Alternatively, you can run: fish_add_path $INSTALL_DIR"
                ;;
            csh|tcsh)
                print_message $YELLOW "Please restart your terminal or run: source $shell_rc"
                ;;
            zsh)
                print_message $YELLOW "Please restart your terminal or run: source $shell_rc"
                print_message $BLUE "Alternatively, you can run: export PATH=\"\$PATH:$INSTALL_DIR\""
                ;;
            bash)
                print_message $YELLOW "Please restart your terminal or run: source $shell_rc"
                print_message $BLUE "Alternatively, you can run: export PATH=\"\$PATH:$INSTALL_DIR\""
                ;;
            *)
                print_message $YELLOW "Please restart your terminal or reload your shell configuration"
                print_message $BLUE "You may need to manually add $INSTALL_DIR to your PATH"
                ;;
        esac
    else
        print_message $GREEN "$INSTALL_DIR is already in your PATH"
    fi
}

# Main installation process
main() {
    print_message $BLUE "🦀 RustyFace Installation Script"
    print_message $BLUE "================================="
    
    # Check shell compatibility first
    check_shell_compatibility
    
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
