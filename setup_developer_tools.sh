#!/bin/bash
set -e

# Global variable for the profile file
declare profile_file

# Function to detect shell and manage profile
manage_profile() {
    profile_file="$HOME/.zshrc"

    # Check if we're in zsh or fall back to bash if zsh is not the current environment
    if [[ -z "$ZSH_VERSION" ]]; then
        if [[ -f "$HOME/.bash_profile" ]]; then
            profile_file="$HOME/.bash_profile"
        else
            echo "Using .zshrc as neither .zshrc nor .bash_profile exists."
        fi
    fi

    # Create profile file if it doesn't exist
    if [[ ! -f "$profile_file" ]]; then
        echo "Creating $profile_file for your shell"
        touch "$profile_file"
    fi

    # Check if Homebrew is in PATH, if not, add it
    if ! grep -q 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$profile_file" && [ -d "/opt/homebrew/bin" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$profile_file"
        echo "Added Homebrew to PATH in $profile_file"
    elif ! grep -q 'eval "$(/usr/local/bin/brew shellenv)"' "$profile_file" && [ -d "/usr/local/bin" ]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$profile_file"
        echo "Added Homebrew to PATH in $profile_file"
    else
        echo "Homebrew is already configured in the PATH."
    fi
}

# Function to update profile for nvm
update_profile_for_nvm() {
    echo "" >> "$profile_file"
    echo "# Initialize NVM" >> "$profile_file"
    if ! grep -q 'export NVM_DIR="$HOME/.nvm"' "$profile_file"; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$profile_file"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$profile_file"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> "$profile_file"
        echo "Added NVM setup to $profile_file"

        reload_profile
    else
        echo "NVM setup is already in the profile."
    fi
}

# Function to update profile for asdf
update_profile_for_asdf() {
    echo "" >> "$profile_file"
    echo "# Initialize ASDF for Ruby" >> "$profile_file"
    if ! grep -q '/opt/homebrew/opt/asdf/libexec/asdf.sh' "$profile_file"; then
        echo '. /opt/homebrew/opt/asdf/libexec/asdf.sh' >> "$profile_file"

        reload_profile
    fi

    echo "Added asdf setup to $profile_file"
}

# Function to update profile for pyenv
update_profile_for_pyenv() {
    echo "" >> "$profile_file"
    echo "# Initialize Pyenv" >> "$profile_file"
    if ! grep -q 'export PYENV_ROOT="$HOME/.pyenv"' "$profile_file"; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$profile_file"
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> "$profile_file"
        echo 'eval "$(pyenv init -)"' >> "$profile_file"
        echo "Added pyenv setup to $profile_file"

        reload_profile
    else
        echo "pyenv setup is already in the profile."
    fi
}

# Function to update profile for jenv
update_profile_for_jenv() {
    echo "# Initialize JENV" >> "$profile_file"
    if ! grep -q 'export PATH="$HOME/.jenv/shims:${PATH}"' "$profile_file"; then
        echo 'eval export PATH="$HOME/.jenv/shims:${PATH}"' >> "$profile_file"
        echo 'export JENV_SHELL=zsh' >> "$profile_file"  # Assuming zsh, adjust if bash or other
        echo 'export JENV_LOADED=1' >> "$profile_file"
        echo 'unset JAVA_HOME' >> "$profile_file"
        echo 'unset JDK_HOME' >> "$profile_file"
        
        # Find the JEnv completions file dynamically
        jenv_completion_file=$(find /opt/homebrew/Cellar/jenv -name "jenv.zsh" 2>/dev/null | head -n 1)
        if [ -f "$jenv_completion_file" ]; then
            echo "source \"$jenv_completion_file\"" >> "$profile_file"
        else
            echo "Warning: JEnv completions not found. Manual setup might be required." >> "$profile_file"
        fi
        
        echo 'jenv rehash 2>/dev/null' >> "$profile_file"
        echo 'jenv refresh-plugins' >> "$profile_file"
        echo 'jenv() {' >> "$profile_file"
        echo '  typeset command' >> "$profile_file"
        echo '  command="$1"' >> "$profile_file"
        echo '  if [ "$#" -gt 0 ]; then' >> "$profile_file"
        echo '    shift' >> "$profile_file"
        echo '  fi' >> "$profile_file"
        echo '' >> "$profile_file"
        echo '  case "$command" in' >> "$profile_file"
        echo '  enable-plugin|rehash|shell|shell-options)' >> "$profile_file"
        echo '    eval `jenv "sh-$command" "$@"`;;' >> "$profile_file"
        echo '  *)' >> "$profile_file"
        echo '    command jenv "$command" "$@";;' >> "$profile_file"
        echo '  esac' >> "$profile_file"
        echo '}' >> "$profile_file"
        echo "Added jenv setup to $profile_file"

        reload_profile
    else
        echo "jenv setup is already in the profile."
    fi
}

# Function to update profile for history settings
update_profile_for_history() {
    echo "" >> "$profile_file"
    echo "# History settings" >> "$profile_file"
    if ! grep -q 'export HISTSIZE=10000' "$profile_file"; then
        echo 'export HISTSIZE=10000' >> "$profile_file"
        echo 'export HISTFILESIZE=10000' >> "$profile_file"
        echo "Added history settings to $profile_file"

        reload_profile
    else
        echo "History settings are already in the profile."
    fi
}

# Function to update profile for Android SDK paths
update_profile_for_android() {
    echo "" >> "$profile_file"
    echo "# Android SDK paths" >> "$profile_file"
    if ! grep -q 'export ANDROID_HOME=$HOME/Library/Android/sdk' "$profile_file"; then
        echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> "$profile_file"
        echo 'export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk' >> "$profile_file"
        echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/emulator' >> "$profile_file"
        echo 'export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools' >> "$profile_file"
        echo "Added Android SDK paths to $profile_file"
    else
        echo "Android SDK paths are already in the profile."
    fi
}

# Function to add .NET to PATH
update_profile_for_dotnet() {
    local dotnet_path=$(find "$HOME/.dotnet" -type d -name "sdk" -print -quit)
    if [ -n "$dotnet_path" ]; then
        dotnet_path="${dotnet_path%/*}"  # Move up one directory from 'sdk'
        if ! grep -q 'export PATH="$PATH:$HOME/.dotnet"' "$profile_file"; then
            echo 'export PATH="$PATH:$HOME/.dotnet"' >> "$profile_file"
            echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> "$profile_file"
            echo 'export PATH="$PATH:$DOTNET_ROOT/tools"' >> "$profile_file"
            echo "Added .NET to PATH in $profile_file"
        else
            echo ".NET is already in PATH in $profile_file"
        fi
        # Reload profile to apply changes
        reload_profile
    else
        echo "Could not find .NET installation directory."
    fi
}

# Function to find JDK version
find_jdk_version() {
    local jdk_dir=$1
    local version_file="$jdk_dir/release"
    if [ -f "$version_file" ]; then
        # Read the file line by line to avoid issues with grep or cut
        while IFS='=' read -r key value; do
            if [[ "$key" == "JAVA_VERSION" ]]; then
                # Remove quotes and replace '-' with '_' for JEnv compatibility
                version="${value//\"/}"
                version="${version//-/}"
                echo "$version"
                return  # Exit the function once we've found and processed the version
            fi
        done < "$version_file"
        echo "Could not find JAVA_VERSION in $version_file"
    else
        echo "Could not find version file at $version_file"
    fi
    return 1  # Indicate failure if we couldn't find the version
}

# Function to ensure jenv version directory exists
ensure_jenv_version_dir() {
    local version=$1
    local version_dir="$HOME/.jenv/versions/zulu64-$version"
    if [ ! -d "$version_dir" ]; then
        echo "Creating directory for JDK version $version..."
        mkdir -p "$version_dir"
    fi
}

reload_profile() {
    # Reload the profile
    source "$profile_file"
}

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    echo "Updating shell profile..."
    manage_profile
else
    echo "Homebrew is already installed."
fi

reload_profile

# Update Homebrew and upgrade formulas
brew update
brew upgrade

# Install Node Version Manager
echo "Installing Node Version Manager (nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash

# Update profile for nvm
update_profile_for_nvm
reload_profile

# Install the latest Node.js version
echo "Installing latest Node.js with nvm..."
nvm install node

reload_profile

# Install tools via Homebrew
echo "Installing Visual Studio Code..."
brew install --cask visual-studio-code

echo "Installing Android Platform Tools..."
brew install android-platform-tools

echo "Installing asdf..."
brew install asdf

# Update profile for asdf
update_profile_for_asdf

echo "Installing Watchman..."
brew install watchman

echo "Installing JDK 8..."
brew install zulu@8

echo "Installing JDK 11..."
brew install zulu@11

echo "Installing PowerShell..."
brew install --cask powershell

echo "Tapping microsoft/git..."
brew tap microsoft/git

echo "Installing Git Credential Manager Core..."
brew install --cask git-credential-manager-core

echo "Installing Azure CLI..."
brew install azure-cli

echo "Installing pyenv..."
brew install pyenv

# Update profile for pyenv
update_profile_for_pyenv

echo "Installing Python 2.7..."
pyenv install 2.7.18  # Note: Use the latest patch version for 2.7 if available

echo "Installing Python 3.13..."
pyenv install 3.13.0  # Adjust to the latest 3.13 version if available

echo "Installing jenv..."
brew install jenv

# Update profile for jenv
update_profile_for_jenv

# Refresh JEnv plugins
jenv refresh-plugins

# Add JDKs to jenv with error handling and directory creation
echo "Adding JDK 8 to jenv..."
jdk8_path="/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home"
jdk8_version=$(find_jdk_version "$jdk8_path")
ensure_jenv_version_dir "$jdk8_version"
if ! jenv add "$jdk8_path"; then
    echo "Failed to add JDK 8 to jenv. Continuing with script..."
fi

echo "Adding JDK 11 to jenv..."
jdk11_path="/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home"
jdk11_version=$(find_jdk_version "$jdk11_path")
ensure_jenv_version_dir "$jdk11_version"
if ! jenv add "$jdk11_path"; then
    echo "Failed to add JDK 11 to jenv. Continuing with script..."
fi

# Setup asdf for Ruby
echo "Adding Ruby plugin to asdf..."
asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git

echo "Installing Ruby 2.7.5 with asdf..."
asdf install ruby 2.7.5

echo "Installing the latest Ruby version with asdf..."
asdf install ruby latest

# Update profile for history settings
update_profile_for_history

# Update profile for Android SDK paths
update_profile_for_android

# Installing .NET
echo "Installing .NET versions..."
dotnet_install_script="/tmp/dotnet-install.sh"
if ! [ -f "$dotnet_install_script" ]; then
    echo "Downloading .NET installation script..."
    curl -sSL -o "$dotnet_install_script" "https://dot.net/v1/dotnet-install.sh"
    chmod +x "$dotnet_install_script"
fi

echo "Installing .NET 6.0.36..."
bash "$dotnet_install_script" -Version 6.0.428

echo "Installing .NET 7.0.20..."
bash "$dotnet_install_script" -Version 7.0.410

echo "Installing .NET 8.0.12..."
bash "$dotnet_install_script" -Version 8.0.405

# Update PATH for .NET
update_profile_for_dotnet

# Reload the profile at the end
reload_profile

echo "Reload your profile with the following command..."
echo "source $profile_file"