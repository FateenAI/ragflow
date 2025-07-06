#!/bin/bash

# Docker Fix Script for RAGFlow GCP Deployment
# This script fixes common Docker startup issues

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

# Function to create Docker daemon configuration
create_docker_config() {
    local config_type="$1"
    mkdir -p /etc/docker
    
    case "$config_type" in
        "full")
            cat << 'EOF' > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "data-root": "/var/lib/docker"
}
EOF
            ;;
        "minimal")
            cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "overlay2"
}
EOF
            ;;
        "vfs")
            cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "vfs",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
            ;;
        *)
            print_error "Unknown config type: $config_type"
            return 1
            ;;
    esac
    
    # Validate JSON
    if python3 -c "import json; json.load(open('/etc/docker/daemon.json'))" 2>/dev/null; then
        print_success "Created valid Docker configuration: $config_type"
        return 0
    else
        print_error "Created invalid JSON configuration"
        return 1
    fi
}

# Enhanced Docker testing function
test_docker_basic() {
    # Test if Docker daemon is running
    if ! docker version > /dev/null 2>&1; then
        return 1
    fi
    
    # Test if Docker can communicate with daemon
    if ! docker info > /dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Test if Docker can run containers
test_docker_containers() {
    # Try to run a simple container
    if docker run --rm hello-world > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Fix attempt 1: Minimal configuration
attempt_minimal_config() {
    print_status "Creating minimal Docker daemon configuration..."
    
    # Stop services
    systemctl stop docker.service || true
    systemctl stop docker.socket || true
    
    # Create minimal config
    mkdir -p /etc/docker
    cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "overlay2"
}
EOF
    
    # Restart services
    systemctl daemon-reload
    systemctl start containerd
    systemctl start docker
    sleep 5
}

# Fix attempt 2: Clean restart with no custom config
attempt_clean_restart() {
    print_status "Removing custom configuration and restarting clean..."
    
    # Stop services
    systemctl stop docker.service || true
    systemctl stop docker.socket || true
    
    # Backup and remove daemon.json
    if [ -f "/etc/docker/daemon.json" ]; then
        mv /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%s)
    fi
    
    # Clean up problematic Docker runtime files
    rm -rf /var/lib/docker/network/files || true
    rm -rf /var/lib/docker/containers/*/mounts || true
    
    # Restart services
    systemctl daemon-reload
    systemctl start containerd
    systemctl start docker
    sleep 5
}

# Fix attempt 3: Alternative storage driver (VFS)
attempt_vfs_driver() {
    print_status "Trying VFS storage driver (slower but more compatible)..."
    
    # Stop services
    systemctl stop docker.service || true
    systemctl stop docker.socket || true
    
    # Create VFS config
    mkdir -p /etc/docker
    cat << 'EOF' > /etc/docker/daemon.json
{
    "storage-driver": "vfs",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    # Restart services
    systemctl daemon-reload
    systemctl start containerd
    systemctl start docker
    sleep 8  # VFS needs more time to initialize
}

# Fix attempt 4: Complete Docker data reset
attempt_complete_reset() {
    print_status "Performing complete Docker data reset..."
    
    # Stop all services
    systemctl stop docker.service || true
    systemctl stop docker.socket || true
    systemctl stop containerd || true
    
    # Remove Docker data (but keep config)
    print_status "Clearing Docker data directories..."
    rm -rf /var/lib/docker/containers/* || true
    rm -rf /var/lib/docker/image/* || true
    rm -rf /var/lib/docker/network/* || true
    rm -rf /var/lib/docker/volumes/* || true
    rm -rf /var/lib/docker/tmp/* || true
    rm -rf /var/lib/docker/trust/* || true
    
    # Recreate basic config
    mkdir -p /etc/docker
    cat << 'EOF' > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    # Start services fresh
    systemctl daemon-reload
    systemctl start containerd
    sleep 3
    systemctl start docker
    sleep 8
}

# Fix attempt 5: Full Docker reinstall
attempt_full_reinstall() {
    print_status "Performing complete Docker reinstall..."
    
    # Stop all services
    systemctl stop docker.service || true
    systemctl stop docker.socket || true
    systemctl stop containerd || true
    
    # Remove all Docker files
    print_status "Removing all Docker data and configuration..."
    rm -rf /var/lib/docker/* || true
    rm -rf /etc/docker/* || true
    rm -rf /var/lib/containerd/* || true
    
    # Reinstall Docker packages
    print_status "Reinstalling Docker packages..."
    apt-get update
    apt-get install --reinstall -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start fresh
    systemctl daemon-reload
    systemctl enable containerd
    systemctl start containerd
    sleep 3
    systemctl enable docker
    systemctl start docker
    sleep 8
}

print_status "Fixing Docker service startup issues..."

# Check if we need to run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

# Preliminary system checks
print_status "Running preliminary system checks..."

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    print_error "Disk usage is ${DISK_USAGE}%. Docker needs sufficient disk space."
    print_status "Consider cleaning up disk space before proceeding."
fi

# Check if kernel modules are available
print_status "Checking kernel modules..."
if ! lsmod | grep -q overlay; then
    print_warning "overlay module not loaded, attempting to load..."
    modprobe overlay || print_warning "Could not load overlay module"
fi

# Check memory
MEMORY_GB=$(free -g | awk 'NR==2{print $2}')
if [ "$MEMORY_GB" -lt 2 ]; then
    print_warning "System has less than 2GB RAM. Docker may have performance issues."
fi

# Kill any conflicting processes
print_status "Checking for conflicting processes..."
if pgrep -f "dockerd" > /dev/null; then
    print_warning "Found running dockerd processes, terminating..."
    pkill -f "dockerd" || true
    sleep 2
fi

# Stop Docker service
print_status "Stopping Docker service..."
systemctl stop docker.service || true
systemctl stop docker.socket || true

# Check Docker daemon configuration
print_status "Checking Docker daemon configuration..."
if [ -f "/etc/docker/daemon.json" ]; then
    print_status "Current daemon.json:"
    cat /etc/docker/daemon.json
    
    # Validate JSON format
    if ! python3 -c "import json; json.load(open('/etc/docker/daemon.json'))" 2>/dev/null; then
        print_warning "Invalid JSON in daemon.json, backing up and creating new one..."
        mv /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%s)
    fi
fi

# Create or fix daemon.json
print_status "Creating proper Docker daemon configuration..."
mkdir -p /etc/docker

cat << 'EOF' > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

# Check for conflicting configuration files
print_status "Checking for configuration conflicts..."
if [ -f "/etc/default/docker" ]; then
    print_warning "Found /etc/default/docker, backing it up..."
    mv /etc/default/docker /etc/default/docker.backup.$(date +%s)
fi

# Reset Docker service
print_status "Resetting Docker service..."
systemctl daemon-reload

# Clean up Docker state if necessary
print_status "Cleaning up Docker state..."
rm -rf /var/lib/docker/network/files || true

# Try to start containerd first
print_status "Starting containerd..."
systemctl start containerd
systemctl enable containerd

# Start Docker service
print_status "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Wait a moment for Docker to fully start
sleep 5

# Test initial Docker state
print_status "Testing Docker installation..."
DOCKER_WORKING=false
fix_attempt=0

if test_docker_basic; then
    print_success "Docker is running successfully!"
    docker version
    DOCKER_WORKING=true
else
    print_error "Docker is not working. Trying progressive fixes..."
    DOCKER_WORKING=false
    
    # Show diagnostic information
    print_status "=== DIAGNOSTIC INFORMATION ==="
    print_status "Docker service status:"
    systemctl status docker.service --no-pager -l || true
    
    print_status "Recent Docker logs:"
    journalctl -u docker.service --no-pager -n 30 || true
    
    print_status "Docker daemon process:"
    ps aux | grep dockerd || true
    
    print_status "=== STARTING PROGRESSIVE FIXES ==="
    
    # Progressive fix attempts
    fix_attempt=1
    max_attempts=5
    
    while [ $fix_attempt -le $max_attempts ] && [ "$DOCKER_WORKING" = "false" ]; do
        case $fix_attempt in
            1)
                print_warning "Fix $fix_attempt/$max_attempts: Trying minimal Docker configuration..."
                attempt_minimal_config
                ;;
            2)
                print_warning "Fix $fix_attempt/$max_attempts: Clean restart with no custom config..."
                attempt_clean_restart
                ;;
            3)
                print_warning "Fix $fix_attempt/$max_attempts: Alternative storage driver (VFS)..."
                attempt_vfs_driver
                ;;
            4)
                print_warning "Fix $fix_attempt/$max_attempts: Complete Docker data reset..."
                attempt_complete_reset
                ;;
            5)
                print_warning "Fix $fix_attempt/$max_attempts: Full Docker reinstall..."
                attempt_full_reinstall
                ;;
        esac
        
        # Test after each fix attempt
        if test_docker_basic; then
            print_success "✅ Fix $fix_attempt worked! Docker is now running."
            DOCKER_WORKING=true
            break
        else
            print_error "❌ Fix $fix_attempt failed. Docker still not working."
            ((fix_attempt++))
            if [ $fix_attempt -le $max_attempts ]; then
                print_status "Trying next fix in 3 seconds..."
                sleep 3
            fi
        fi
    done
    
    # Final failure handling
    if [ "$DOCKER_WORKING" = "false" ]; then
        print_error "🚫 All automated fixes failed. Manual intervention required."
        print_status ""
        print_status "=== MANUAL TROUBLESHOOTING STEPS ==="
        print_status "1. Check system logs: sudo journalctl -u docker.service -f"
        print_status "2. Check kernel messages: sudo dmesg | grep -i docker"
        print_status "3. Verify kernel modules: sudo modprobe overlay && sudo modprobe br_netfilter"
        print_status "4. Check disk space: df -h"
        print_status "5. Check memory: free -h"
        print_status "6. Try manual start: sudo dockerd --debug"
        print_status ""
        print_status "Common issues:"
        echo "  • Kernel modules missing (overlay, br_netfilter)"
        echo "  • Insufficient disk space (need >1GB free)"
        echo "  • Memory issues (need >512MB available)"
        echo "  • SELinux/AppArmor policy conflicts"
        echo "  • Virtualization platform limitations"
        echo "  • Conflicting container runtimes"
        print_status ""
        exit 1
    fi
fi

# Final comprehensive testing
print_status "=== COMPREHENSIVE DOCKER TESTING ==="

# Test 1: Basic Docker functionality
print_status "Testing basic Docker functionality..."
if test_docker_basic; then
    print_success "✅ Docker daemon is running and responding"
else
    print_error "❌ Docker daemon is not responding properly"
fi

# Test 2: Container execution
print_status "Testing container execution..."
if test_docker_containers; then
    print_success "✅ Docker can run containers successfully"
else
    print_warning "⚠️  Docker started but can't run containers yet"
    print_status "This might resolve itself - trying once more..."
    sleep 10
    if test_docker_containers; then
        print_success "✅ Docker containers now working after delay"
    else
        print_warning "⚠️  Containers still not working - may need manual intervention"
    fi
fi

# Test 3: Docker Compose functionality
print_status "Testing Docker Compose..."
if command -v docker-compose > /dev/null 2>&1; then
    if docker-compose version > /dev/null 2>&1; then
        print_success "✅ Docker Compose is available and working"
    else
        print_warning "⚠️  Docker Compose installed but not responding"
    fi
elif docker compose version > /dev/null 2>&1; then
    print_success "✅ Docker Compose (plugin) is available and working"
else
    print_warning "⚠️  Docker Compose not available - may need installation"
fi

# Show final system information
print_status "=== FINAL SYSTEM STATUS ==="
echo "Docker Version:"
docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}' 2>/dev/null || echo "Version info unavailable"

echo ""
echo "Docker Info Summary:"
docker system info --format 'Storage Driver: {{.Driver}} | Containers: {{.Containers}} | Images: {{.Images}}' 2>/dev/null || echo "System info unavailable"

echo ""
echo "System Resources:"
echo "Disk usage: $(df / | tail -1 | awk '{print $5}')"
echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"

echo ""
echo "Docker Service Status:"
systemctl is-active docker.service 2>/dev/null || echo "Status unknown"

print_success "🐳 Docker fix process completed!"

# Generate a summary of what was fixed
if [ "$DOCKER_WORKING" = "true" ]; then
    print_status ""
    print_status "=== SUMMARY OF FIXES APPLIED ==="
    if [ $fix_attempt -eq 1 ]; then
        echo "✅ Fixed with: Minimal Docker configuration (overlay2 storage)"
    elif [ $fix_attempt -eq 2 ]; then
        echo "✅ Fixed with: Clean restart (removed custom config)"
    elif [ $fix_attempt -eq 3 ]; then
        echo "✅ Fixed with: VFS storage driver (more compatible but slower)"
        echo "💡 Consider switching back to overlay2 later for better performance"
    elif [ $fix_attempt -eq 4 ]; then
        echo "✅ Fixed with: Complete Docker data reset"
    elif [ $fix_attempt -eq 5 ]; then
        echo "✅ Fixed with: Full Docker reinstall"
    else
        echo "✅ Docker was already working"
    fi
fi
print_status ""
print_status "=== NEXT STEPS ==="
print_status "1. You can now continue with RAGFlow setup"
print_status "2. To start RAGFlow: cd /path/to/ragflow && docker-compose up -d"
print_status "3. To monitor: docker-compose logs -f"
print_status "4. If issues persist, check: sudo journalctl -u docker.service -f"
print_status ""
