#!/bin/bash

curl -s https://raw.githubusercontent.com/arun993/mylogo/refs/heads/main/logo.sh | bash
sleep 3

BOLD=$(tput bold)
NORMAL=$(tput sgr0)
PINK='\033[1;35m'


show() {
    case $2 in
        "error")
            echo -e "${PINK}${BOLD}❌ $1${NORMAL}"
            ;;
        "progress")
            echo -e "${PINK}${BOLD}⏳ $1${NORMAL}"
            ;;
        *)
            echo -e "${PINK}${BOLD}✅ $1${NORMAL}"
            ;;
    esac
}
# Prompt the user for the account number
read -p "Enter Account Number: " Account_Number

# Remove existing dir
rm -rf "$HOME/network-api$Account_Number"

# Create the directory
mkdir "$HOME/network-api$Account_Number"  # Added $HOME to create in the correct path

echo "Proceeding with Account $Account_Number"

SERVICE_NAME="nexus$Account_Number"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

show "Installing Rust..." "progress"
if ! source <(wget -O - https://raw.githubusercontent.com/zunxbt/installation/main/rust.sh); then
    show "Failed to install Rust." "error"
    exit 1
fi

show "Updating package list..." "progress"
if ! sudo apt update; then
    show "Failed to update package list." "error"
    exit 1
fi

if ! command -v git &> /dev/null; then
    show "Git is not installed. Installing git..." "progress"
    if ! sudo apt install git -y; then
        show "Failed to install git." "error"
        exit 1
    fi
else
    show "Git is already installed."
fi

sleep 3

show "Cloning Nexus-XYZ network API repository..." "progress"
if ! git clone https://github.com/nexus-xyz/network-api.git "$HOME/network-api$Account_Number"; then
    show "Failed to clone the repository." "error"
    exit 1
fi

cd $HOME/network-api$Account_Number/clients/cli

show "Installing required dependencies..." "progress"
if ! sudo apt install pkg-config libssl-dev -y; then
    show "Failed to install dependencies." "error"
    exit 1
fi

if systemctl is-active --quiet nexus$Account_Number.service; then
    show "nexus$Account_Number.service is currently running. Stopping and disabling it..."
    sudo systemctl stop nexus$Account_Number.service
    sudo systemctl disable nexus$Account_Number.service
else
    show "nexus$Account_Number.service is not running."
fi

show "Creating systemd service..." "progress"
if ! sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service Instance $Account_Number
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/network-api$Account_Number/clients/cli
Environment=NONINTERACTIVE=1
ExecStart=$HOME/.cargo/bin/cargo run --release --bin prover -- beta.orchestrator.nexus.xyz  --service-id=$Account_Number
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"; then
    show "Failed to create the systemd service file." "error"
    exit 1
fi

show "Reloading systemd and starting the service..." "progress"
if ! sudo systemctl daemon-reload; then
    show "Failed to reload systemd." "error"
    exit 1
fi

if ! sudo systemctl start $SERVICE_NAME.service; then
    show "Failed to start the service." "error"
    exit 1
fi

if ! sudo systemctl enable $SERVICE_NAME.service; then
    show "Failed to enable the service." "error"
    exit 1
fi

show "Nexus Prover installation and service setup complete for Account Number $Account_Number , Now you can run this script again for next account!"
show "You can check Nexus Prover logs using this command : journalctl -u nexus$Account_Number.service -fn 50"
echo
