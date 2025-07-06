#!/bin/bash

# GitHub Actions Self-Hosted Runner Setup Script for RAGFlow on GCP
# This script sets up a self-hosted GitHub Actions runner on a GCP VM for RAGFlow deployment

set -e

# Configuration
RUNNER_VERSION="2.317.0"  # Update this to the latest version
RUNNER_USER="runner"
RUNNER_HOME="/home/$RUNNER_USER"
RUNNER_DIR="$RUNNER_HOME/actions-runner"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

print_status "Starting GitHub Actions Runner setup for RAGFlow..."

# Update system packages
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    htop \
    vim \
    jq \
    build-essential

# Install Docker Engine
print_status "Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker Engine installed successfully"
else
    print_success "Docker Engine is already installed"
fi

# Configure Docker daemon
print_status "Configuring Docker daemon..."
mkdir -p /etc/docker

cat << 'EOF' > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "default-ulimits": {
        "memlock": {
            "Hard": -1,
            "Name": "memlock",
            "Soft": -1
        }
    }
}
EOF

systemctl restart docker
print_success "Docker daemon configured"

# Test Docker installation and fix if needed
print_status "Testing Docker installation..."
if docker version > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    print_success "Docker is working properly"
    
    # Test container execution
    if docker run --rm hello-world > /dev/null 2>&1; then
        print_success "Docker can run containers successfully"
    else
        print_warning "Docker daemon running but containers may have issues"
    fi
else
    print_warning "Docker not working properly. Running fix script..."
    
    # Copy the fix script if it exists in the current directory
    if [ -f "./fix-docker.sh" ]; then
        print_status "Running Docker fix script..."
        chmod +x ./fix-docker.sh
        ./fix-docker.sh
    else
        print_warning "Docker fix script not found. Attempting basic fixes..."
        
        # Basic Docker troubleshooting
        systemctl stop docker.service || true
        systemctl stop docker.socket || true
        
        # Create minimal config
        cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "overlay2"
}
EOF
        
        systemctl daemon-reload
        systemctl start containerd
        systemctl start docker
        sleep 5
        
        if docker version > /dev/null 2>&1; then
            print_success "Docker fixed with basic troubleshooting"
        else
            print_error "Docker still not working. Manual intervention may be required."
        fi
    fi
fi

# Create runner user
print_status "Creating runner user..."
if ! id "$RUNNER_USER" &>/dev/null; then
    useradd -m -s /bin/bash $RUNNER_USER
    usermod -aG docker $RUNNER_USER
    usermod -aG sudo $RUNNER_USER
    print_success "Runner user created and added to docker and sudo groups"
else
    print_success "Runner user already exists"
    usermod -aG docker $RUNNER_USER
    usermod -aG sudo $RUNNER_USER
fi

# Allow runner user to use sudo without password for Docker commands
print_status "Configuring sudo permissions for runner..."
cat << EOF > /etc/sudoers.d/runner
$RUNNER_USER ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /usr/local/bin/docker-compose, /usr/bin/systemctl
$RUNNER_USER ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chmod, /bin/chown
$RUNNER_USER ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install
EOF

# Set up runner directory
print_status "Setting up runner directory..."
mkdir -p $RUNNER_DIR
cd $RUNNER_DIR

# Download and extract GitHub Actions runner
print_status "Downloading GitHub Actions runner v$RUNNER_VERSION..."
RUNNER_ARCH=$(uname -m)
if [ "$RUNNER_ARCH" = "x86_64" ]; then
    RUNNER_ARCH="x64"
elif [ "$RUNNER_ARCH" = "aarch64" ]; then
    RUNNER_ARCH="arm64"
fi

RUNNER_URL="https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-$RUNNER_ARCH-$RUNNER_VERSION.tar.gz"

wget -O actions-runner-linux.tar.gz $RUNNER_URL
tar xzf actions-runner-linux.tar.gz
rm actions-runner-linux.tar.gz

# Install runner dependencies
print_status "Installing runner dependencies..."
./bin/installdependencies.sh

# Change ownership to runner user
chown -R $RUNNER_USER:$RUNNER_USER $RUNNER_HOME

# Create systemd service for the runner
print_status "Creating systemd service..."
cat << EOF > /etc/systemd/system/github-runner.service
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=$RUNNER_USER
WorkingDirectory=$RUNNER_DIR
ExecStart=$RUNNER_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=github-runner

[Install]
WantedBy=multi-user.target
EOF

# Enable the service (but don't start it yet)
systemctl daemon-reload
systemctl enable github-runner

# Create configuration script for the runner
print_status "Creating runner configuration script..."
cat << 'EOF' > $RUNNER_DIR/configure-runner.sh
#!/bin/bash

# This script configures the GitHub Actions runner
# Run this script as the runner user after setting up the repository

set -e

# Check if we're running as the runner user
if [ "$(whoami)" != "runner" ]; then
    echo "Error: This script must be run as the runner user"
    echo "Switch to runner user: sudo su - runner"
    echo "Then run: $RUNNER_DIR/configure-runner.sh"
    exit 1
fi

echo "GitHub Actions Runner Configuration"
echo "=================================="

# Prompt for repository URL
read -p "Enter your GitHub repository URL (e.g., https://github.com/yourorg/ragflow): " REPO_URL

# Prompt for registration token
echo ""
echo "To get a registration token:"
echo "1. Go to your repository settings"
echo "2. Navigate to Actions -> Runners"
echo "3. Click 'New self-hosted runner'"
echo "4. Copy the token from the configuration commands"
echo ""
read -p "Enter the registration token: " REG_TOKEN

# Prompt for runner name and labels
read -p "Enter runner name (default: ragflow-gcp-runner): " RUNNER_NAME
RUNNER_NAME=${RUNNER_NAME:-ragflow-gcp-runner}

read -p "Enter runner labels (default: self-hosted,linux,ragflow-gcp): " RUNNER_LABELS
RUNNER_LABELS=${RUNNER_LABELS:-self-hosted,linux,ragflow-gcp}

# Configure the runner
echo "Configuring runner..."
./config.sh \
    --url "$REPO_URL" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work _work \
    --unattended

echo "Runner configured successfully!"
echo ""
echo "To start the runner service:"
echo "sudo systemctl start github-runner"
echo "sudo systemctl status github-runner"
EOF

chmod +x $RUNNER_DIR/configure-runner.sh
chown $RUNNER_USER:$RUNNER_USER $RUNNER_DIR/configure-runner.sh

# Create RAGFlow-specific directories
print_status "Creating RAGFlow directories..."
sudo -u $RUNNER_USER mkdir -p $RUNNER_HOME/ragflow-deployment
sudo -u $RUNNER_USER mkdir -p $RUNNER_HOME/ragflow-deployment/logs
sudo -u $RUNNER_USER mkdir -p $RUNNER_HOME/ragflow-deployment/data

# Create firewall rules script
print_status "Creating firewall configuration script..."
cat << 'EOF' > /root/configure-firewall.sh
#!/bin/bash

# Configure firewall for RAGFlow services
echo "Configuring firewall rules for RAGFlow..."

# Install ufw if not present
if ! command -v ufw &> /dev/null; then
    apt-get update
    apt-get install -y ufw
fi

# Reset firewall
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# SSH (adjust port if needed)
ufw allow 22/tcp comment "SSH"

# RAGFlow main service
ufw allow 9380/tcp comment "RAGFlow Main Service"

# HTTP and HTTPS
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Elasticsearch
ufw allow 1200/tcp comment "Elasticsearch"

# Kibana
ufw allow 6601/tcp comment "Kibana"

# OpenSearch (if used)
ufw allow 1201/tcp comment "OpenSearch"

# Enable firewall
ufw --force enable

echo "Firewall configured successfully!"
ufw status verbose
EOF

chmod +x /root/configure-firewall.sh

# Create monitoring script
print_status "Creating monitoring script..."
cat << 'EOF' > $RUNNER_HOME/monitor-ragflow.sh
#!/bin/bash

# RAGFlow Monitoring Script
# Run this script to check the status of RAGFlow services

echo "RAGFlow Service Status"
echo "====================="

cd $HOME/actions-runner/_work/*/ragflow/docker 2>/dev/null || {
    echo "No RAGFlow deployment found"
    exit 1
}

echo "Docker Compose Services:"
sudo docker compose ps

echo ""
echo "Service Health Checks:"

# Check main service
if curl -s http://localhost:9380/health > /dev/null; then
    echo "✅ RAGFlow main service is healthy"
else
    echo "❌ RAGFlow main service is not responding"
fi

# Check Elasticsearch
if curl -s http://localhost:1200/_cluster/health > /dev/null; then
    echo "✅ Elasticsearch is healthy"
else
    echo "❌ Elasticsearch is not responding"
fi

echo ""
echo "System Resources:"
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h
echo ""
echo "Docker System Info:"
sudo docker system df
EOF

chmod +x $RUNNER_HOME/monitor-ragflow.sh
chown $RUNNER_USER:$RUNNER_USER $RUNNER_HOME/monitor-ragflow.sh

# Create helpful aliases for the runner user
print_status "Creating helpful aliases..."
cat << 'EOF' >> $RUNNER_HOME/.bashrc

# RAGFlow aliases
alias ragflow-status='~/monitor-ragflow.sh'
alias ragflow-logs='cd ~/actions-runner/_work/*/ragflow/docker && sudo docker compose logs -f'
alias ragflow-restart='cd ~/actions-runner/_work/*/ragflow/docker && sudo docker compose restart'
alias ragflow-stop='cd ~/actions-runner/_work/*/ragflow/docker && sudo docker compose down'
alias ragflow-start='cd ~/actions-runner/_work/*/ragflow/docker && sudo docker compose up -d'
EOF

# Print final instructions
print_success "GitHub Actions Runner setup completed!"
print_status "Next steps:"
echo ""
echo "1. Configure the runner (run as runner user):"
echo "   sudo su - runner"
echo "   cd $RUNNER_DIR"
echo "   ./configure-runner.sh"
echo ""
echo "2. Start the runner service:"
echo "   sudo systemctl start github-runner"
echo "   sudo systemctl status github-runner"
echo ""
echo "3. Configure firewall (optional):"
echo "   /root/configure-firewall.sh"
echo ""
echo "4. Monitor RAGFlow services:"
echo "   sudo su - runner"
echo "   ./monitor-ragflow.sh"
echo ""
print_warning "Important: Make sure to configure the repository secrets and variables as listed in the documentation!"

# Display system information
print_status "System Information:"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk 'NR==2{print $2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $4}') available"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

print_success "Setup completed successfully! 🎉"
