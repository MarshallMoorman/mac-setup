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
}

# Function to update profile for homebrew
update_profile_for_homebrew() {
    echo "" >> "$profile_file"
    echo "# Initialize Homebrew" >> "$profile_file"
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
    echo "" >> "$profile_file"
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
            echo "Warning: JEnv completions not found. Manual setup might be required."
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

# Update profile for rbenv
update_profile_for_rbenv() {
    echo "# rbenv settings" >> "$profile_file"
    if ! grep -q 'eval "$(rbenv init -)"' "$profile_file"; then
        echo 'eval "$(rbenv init -)"' >> "$profile_file"
        echo "Added rbenv setup to $profile_file"
        reload_profile
    else
        echo "rbenv setup is already in the profile."
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

# Creating NuGet configuration file
create_nuget_config() {
    mkdir -p "$HOME/.nuget/NuGet"
    
    local nuget_config_file="$HOME/.nuget/NuGet/NuGet.config"
    if [ ! -f "$nuget_config_file" ]; then
        echo "Creating NuGet configuration file..."
        cat << EOF > "$nuget_config_file"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="Elevate" value="https://pkgs.dev.azure.com/elevate-apps/Elevate/_packaging/Elevate/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
EOF
        echo "NuGet configuration file created at $nuget_config_file"
    else
        echo "NuGet configuration file already exists at $nuget_config_file"
    fi
}

# Creating npm configuration file
create_npm_config() {
    local npm_config_file="$HOME/.npmrc"
    if [ ! -f "$npm_config_file" ]; then
        echo "Creating npm configuration file..."
        cat << EOF > "$npm_config_file"
registry=https://registry.npmjs.org/
always-auth=true
@elevate:registry=https://pkgs.dev.azure.com/elevate-apps/Elevate/_packaging/Elevate/npm/registry
EOF
        echo "NPM configuration file created at $npm_config_file"
    else
        echo "NPM configuration file already exists at $npm_config_file"
    fi
}

# Creating Maven configuration file
create_maven_config() {
    local maven_config_dir="$HOME/.m2"
    local maven_config_file="$maven_config_dir/settings.xml"
    
    if [ ! -d "$maven_config_dir" ]; then
        mkdir -p "$maven_config_dir"
    fi

    if [ ! -f "$maven_config_file" ]; then
        echo "Creating Maven configuration file..."
        cat << EOF > "$maven_config_file"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>maven-central</id>
      <name>Maven Central Mirror</name>
      <url>https://repo1.maven.org/maven2/</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
  <servers>
    <server>
      <id>Elevate</id>
      <username>elevate-apps</username>
      <password>[PERSONAL_ACCESS_TOKEN]</password>
    </server>
  </servers>
  <profiles>
    <profile>
      <id>custom-repos</id>
      <repositories>
        <repository>
          <id>Elevate</id>
          <url>https://pkgs.dev.azure.com/elevate-apps/Elevate/_packaging/Elevate/maven/v1</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>custom-repos</activeProfile>
  </activeProfiles>
</settings>
EOF
        echo "Maven configuration file created at $maven_config_file"
    else
        echo "Maven configuration file already exists at $maven_config_file"
    fi
}

# Check and adjust permissions for Zsh if necessary
check_and_adjust_zsh_permissions() {
    local zsh_dir="/usr/local/share/zsh"
    local zsh_site_functions="${zsh_dir}/site-functions"
    local current_user=$(whoami)

    # Check if the directories exist
    if [ ! -d "$zsh_dir" ] || [ ! -d "$zsh_site_functions" ]; then
        echo "Warning: Zsh directories not found at expected locations. Skipping permission adjustments."
        return
    fi

    # Check ownership
    local current_owner=$(stat -f "%Su" "$zsh_dir")
    if [ "$current_owner" != "$current_user" ]; then
        echo "Changing ownership of Zsh directories to $current_user..."
        sudo chown -R "$current_user" "$zsh_dir" "$zsh_site_functions"
    else
        echo "Zsh directories are already owned by $current_user."
    fi

    # Check write permissions
    if [ ! -w "$zsh_dir" ] || [ ! -w "$zsh_site_functions" ]; then
        echo "Adding write permissions to Zsh directories..."
        chmod u+w "$zsh_dir" "$zsh_site_functions"
    else
        echo "Zsh directories already have write permissions."
    fi
}

reload_profile() {
    # Reload the profile
    source "$profile_file"
}

# Determine the architecture
arch_name="$(uname -m)"

# Load the profile variables
manage_profile
check_and_adjust_zsh_permissions
reload_profile

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    echo "Updating shell profile..."
    update_profile_for_homebrew
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

echo "Installing Watchman..."
brew install watchman

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

echo "Installing Zoom..."
brew install --cask zoom

echo "Installing Postman..."
brew install --cask postman

echo "Installing Fastlane..."
brew install fastlane

echo "Installing Android Studio..."
brew install --cask android-studio

echo "Tapping mobile-dev-inc/tap..."
brew tap mobile-dev-inc/tap

echo "Installing Maestro..."
brew install maestro

echo "Installing Vysor..."
brew install --cask vysor

# Installing Azure Artifacts Credential Provider
sh -c "$(curl -fsSL https://aka.ms/install-artifacts-credprovider.sh)"

# Creating NuGet configuration
create_nuget_config

# Creating NPM configuration
create_npm_config

# Creating Maven configuration
create_maven_config

# Install Maven
echo "Installing Maven..."
brew install maven

# Install rbenv
echo "Installing rbenv..."
brew install rbenv

# Update profile for rbenv
update_profile_for_rbenv
reload_profile

# Install Ruby versions with rbenv
echo "Installing Ruby 2.6.10..."
rbenv install 2.6.10

# Find the latest Ruby version available
latest_ruby=$(rbenv install -l | grep -E '^[0-9]' | tail -1 | tr -d ' ')

echo "Installing latest Ruby ($latest_ruby)..."
rbenv install "$latest_ruby"

# Set global Ruby version to the latest installed
echo "Setting global Ruby to the latest version ($latest_ruby)..."
rbenv global "$latest_ruby"

# Install Cocoapods for the latest Ruby
echo "Switching to latest Ruby ($latest_ruby)..."
rbenv shell "$latest_ruby"
echo "Installing Cocoapods version 1.16.2..."
gem install cocoapods -v 1.16.2

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

# Add JDK 11 to jenv with error handling and directory creation
echo "Adding JDK 11 to jenv..."
jdk11_path="/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home"
jdk11_version=$(find_jdk_version "$jdk11_path")
ensure_jenv_version_dir "$jdk11_version"
if ! jenv add "$jdk11_path"; then
    echo "Failed to add JDK 11 to jenv. Continuing with script..."
fi

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

echo "Installing .NET 6.0.428..."
bash "$dotnet_install_script" -Version 6.0.428

echo "Installing .NET 7.0.410..."
bash "$dotnet_install_script" -Version 7.0.410

echo "Installing .NET 8.0.405..."
bash "$dotnet_install_script" -Version 8.0.405

# Update PATH for .NET
update_profile_for_dotnet

# Reload the profile at the end
reload_profile

echo "Setting default global ruby version to 2.6.10..."
rbenv global 2.6.10

echo "Setting default global python version to 2.7.18 and 3.13.0..."
pyenv global 2.7.18 3.13.0

echo "Setting default global node version to latest..."
nvm alias default node

echo "Setting default global jdk version to $jdk11_version..."
jenv global "$jdk11_version"

echo "Reload your profile with the following command..."
echo "source $profile_file"