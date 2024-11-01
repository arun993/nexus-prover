#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Constants for text formatting
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
PINK='\033[1;35m'

# Function to display messages with formatting and type
show() {
    local message="$1"
    local type="${2:-}"
    case $type in
        "error")
            printf "${PINK}${BOLD}❌ %s${NORMAL}\n" "$message" >&2
            ;;
        "progress")
            printf "${PINK}${BOLD}⏳ %s${NORMAL}\n" "$message"
            ;;
        *)
            printf "${PINK}${BOLD}✅ %s${NORMAL}\n" "$message"
            ;;
    esac
}

# Function to handle errors and clean exit
trap 'show "An error occurred. Exiting." "error"; exit 1' ERR
trap 'show "Script terminated by user." "error"; exit 1' SIGINT SIGTERM

# Prompt user for account number
read -r -p "Enter Account Number: " account_number
if [[ -z "$account_number" || ! "$account_number" =~ ^[0-9]+$ ]]; then
    show "Invalid account number. Must be a non-empty numeric value." "error"
    exit 1
fi

# Directory setup
dir_path="$HOME/network-api$account_number"
rm -rf "$dir_path"
mkdir "$dir_path"

show "Proceeding with Account $account_number"

# Service configuration
SERVICE_NAME="nexus$account_number"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Install Rust
show "Installing Rust..." "progress"
if ! source <(wget -qO- https://raw.githubusercontent.com/zunxbt/installation/main/rust.sh); then
    show "Failed to install Rust." "error"
    exit 1
fi

# Update package list
show "Updating package list..." "progress"
sudo apt update

# Check and install Git
if ! command -v git &>/dev/null; then
    show "Git is not installed. Installing git..." "progress"
    sudo apt install git -y
else
    show "Git is already installed."
fi

# Clone repository
show "Cloning Nexus-XYZ network API repository..." "progress"
if ! git clone https://github.com/nexus-xyz/network-api.git "$dir_path"; then
    show "Failed to clone the repository." "error"
    exit 1
fi

cd "$dir_path/clients/cli" || exit 1

# Install dependencies
show "Installing required dependencies..." "progress"
sudo apt install -y pkg-config libssl-dev

# Stop existing service if running
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    show "$SERVICE_NAME.service is currently running. Stopping and disabling it..."
    sudo systemctl stop "$SERVICE_NAME.service"
    sudo systemctl disable "$SERVICE_NAME.service"
else
    show "$SERVICE_NAME.service is not running."
fi

# Create systemd service file
show "Creating systemd service..." "progress"
sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service Instance $account_number
After=network.target

[Service]
User=$USER
WorkingDirectory=$dir_path/clients/cli
Environment=NONINTERACTIVE=1
ExecStart=$HOME/.cargo/bin/cargo run --release --bin prover -- beta.orchestrator.nexus.xyz --service-id=$account_number
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"

# Reload systemd and start service
show "Reloading systemd and starting the service..." "progress"
sudo systemctl daemon-reload
sudo systemctl start "$SERVICE_NAME.service"
sudo systemctl enable "$SERVICE_NAME.service"

show "Nexus Prover installation and service setup complete for Account Number $account_number. Run this script again for the next account!"
show "You can check Nexus Prover logs using: journalctl -u $SERVICE_NAME.service -fn 50"
