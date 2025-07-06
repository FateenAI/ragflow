#!/bin/bash

# Complete Docker Setup and Test Script for RAGFlow
# This script installs Docker, tests it, and fixes any issues automatically

set -e

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

echo "=== RAGFlow Docker Complete Setup Script ==="
echo "This script will:"
echo "1. Install Docker if not present"
echo "2. Test Docker functionality"
echo "3. Fix any Docker issues automatically"
echo "4. Verify final working state"
echo ""

# Step 1: Install Docker if needed
print_status "=== STEP 1: DOCKER INSTALLATION ==="

if ! command -v docker &> /dev/null; then
    print_status "Docker not found. Installing Docker Engine..."
    
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
    docker --version
fi

# Step 2: Run Docker test (demonstration)
print_status "=== STEP 2: DOCKER TESTING (DEMO) ==="

if [ -f "./test-fix-docker.sh" ]; then
    print_status "Running Docker test script demonstration..."
    chmod +x ./test-fix-docker.sh
    ./test-fix-docker.sh
    echo ""
else
    print_warning "Docker test script not found, skipping demonstration"
fi

# Step 3: Test actual Docker functionality
print_status "=== STEP 3: ACTUAL DOCKER TESTING ==="

# Test basic Docker functionality
docker_working=false

print_status "Testing Docker daemon connection..."
if docker version > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    print_success "✅ Docker daemon is responding"
    
    print_status "Testing container execution..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        print_success "✅ Docker can run containers successfully"
        docker_working=true
    else
        print_warning "⚠️  Docker daemon running but can't execute containers"
    fi
else
    print_warning "⚠️  Docker daemon not responding properly"
fi

# Step 4: Fix Docker if needed
if [ "$docker_working" = "false" ]; then
    print_status "=== STEP 4: DOCKER REPAIR ==="
    
    if [ -f "./fix-docker.sh" ]; then
        print_status "Running comprehensive Docker fix script..."
        chmod +x ./fix-docker.sh
        ./fix-docker.sh
    else
        print_warning "Docker fix script not found. Running basic fixes..."
        
        # Basic Docker troubleshooting
        systemctl stop docker.service || true
        systemctl stop docker.socket || true
        
        # Create minimal config
        mkdir -p /etc/docker
        cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "overlay2"
}
EOF
        
        systemctl daemon-reload
        systemctl start containerd
        systemctl start docker
        sleep 5
        
        if docker version > /dev/null 2>&1 && docker run --rm hello-world > /dev/null 2>&1; then
            print_success "Docker fixed with basic troubleshooting"
        else
            print_error "Docker still not working. Manual intervention may be required."
        fi
    fi
else
    print_success "=== STEP 4: DOCKER REPAIR (SKIPPED - WORKING) ==="
    print_success "Docker is already working properly!"
fi

# Final verification
print_status "=== FINAL VERIFICATION ==="

print_status "Docker version:"
docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}' 2>/dev/null || echo "Version info unavailable"

print_status "Docker system info:"
docker system info --format 'Storage Driver: {{.Driver}} | Containers: {{.Containers}} | Images: {{.Images}}' 2>/dev/null || echo "System info unavailable"

print_status "Testing hello-world container:"
if docker run --rm hello-world > /dev/null 2>&1; then
    print_success "✅ Container execution test passed"
else
    print_error "❌ Container execution test failed"
fi

print_status "Docker Compose availability:"
if docker compose version > /dev/null 2>&1; then
    print_success "✅ Docker Compose (plugin) available"
elif command -v docker-compose > /dev/null 2>&1; then
    print_success "✅ Docker Compose (standalone) available"
else
    print_warning "⚠️  Docker Compose not available"
fi

echo ""
print_success "🐳 Docker setup and testing completed!"
print_status ""
print_status "=== NEXT STEPS FOR RAGFLOW ==="
print_status "1. Ensure your user is in the docker group: sudo usermod -aG docker \$USER"
print_status "2. Log out and back in, or run: newgrp docker"
print_status "3. Test without sudo: docker run hello-world"
print_status "4. Navigate to RAGFlow directory and run: docker-compose up -d"
print_status ""
