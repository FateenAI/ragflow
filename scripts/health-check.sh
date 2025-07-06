#!/bin/bash

# RAGFlow Health Check and Maintenance Script
# This script performs comprehensive health checks and basic maintenance tasks

set -e

# Configuration
RAGFLOW_PORT=${SVR_HTTP_PORT:-9380}
ES_PORT=${ES_PORT:-1200}
KIBANA_PORT=${KIBANA_PORT:-6601}
MYSQL_PORT=${MYSQL_PORT:-5455}
REDIS_PORT=${REDIS_PORT:-6379}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_service() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    if curl -s --connect-timeout 5 --max-time 10 "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        print_success "$service_name is healthy (port $port)"
        return 0
    else
        print_error "$service_name is not responding (port $port)"
        return 1
    fi
}

check_docker_service() {
    local service_name=$1
    local container_pattern=$2
    
    if sudo docker ps --filter "name=$container_pattern" --filter "status=running" | grep -q "$container_pattern"; then
        print_success "$service_name container is running"
        return 0
    else
        print_error "$service_name container is not running"
        return 1
    fi
}

# Main health check function
main() {
    print_header "RAGFlow System Health Check - $(date)"
    
    # Check if we're in the right directory
    if [ ! -f "docker-compose.yml" ]; then
        # Try to find the docker compose file
        COMPOSE_DIR=$(find $HOME -name "docker-compose.yml" -path "*/ragflow/docker/*" 2>/dev/null | head -1)
        if [ -n "$COMPOSE_DIR" ]; then
            cd "$(dirname "$COMPOSE_DIR")"
            print_status "Found docker-compose.yml at $(pwd)"
        else
            print_error "Could not find RAGFlow docker-compose.yml file"
            echo "Please run this script from the RAGFlow docker directory"
            exit 1
        fi
    fi
    
    # System Resource Check
    print_header "System Resources"
    
    # Memory check
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "Memory Usage: ${MEMORY_USAGE}%"
    if [ "$(echo "$MEMORY_USAGE > 90" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        print_warning "High memory usage detected (${MEMORY_USAGE}%)"
    else
        print_success "Memory usage is acceptable (${MEMORY_USAGE}%)"
    fi
    
    # Disk check
    DISK_USAGE=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "Disk Usage: ${DISK_USAGE}%"
    if [ "$DISK_USAGE" -gt 85 ]; then
        print_warning "High disk usage detected (${DISK_USAGE}%)"
    else
        print_success "Disk usage is acceptable (${DISK_USAGE}%)"
    fi
    
    # Docker system check
    print_header "Docker System Status"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! sudo docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Docker daemon is running"
    
    # Docker Compose Services Check
    print_header "Docker Compose Services"
    
    echo "Service Status:"
    sudo docker compose ps
    echo ""
    
    # Individual service health checks
    print_header "Service Health Checks"
    
    FAILED_SERVICES=0
    
    # RAGFlow main service
    if check_service "RAGFlow Main Service" "$RAGFLOW_PORT" "/api/v1/health"; then
        :
    else
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
    fi
    
    # Elasticsearch
    if check_docker_service "Elasticsearch" "ragflow-es"; then
        if check_service "Elasticsearch" "$ES_PORT" "/_cluster/health"; then
            :
        else
            FAILED_SERVICES=$((FAILED_SERVICES + 1))
        fi
    else
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
    fi
    
    # MySQL
    if check_docker_service "MySQL" "ragflow-mysql"; then
        :
    else
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
    fi
    
    # Redis
    if check_docker_service "Redis" "ragflow-redis"; then
        :
    else
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
    fi
    
    # Kibana (optional)
    if check_docker_service "Kibana" "ragflow-kibana"; then
        check_service "Kibana" "$KIBANA_PORT" "/"
    else
        print_warning "Kibana container is not running (this may be expected)"
    fi
    
    # Docker resource usage
    print_header "Docker Resource Usage"
    
    echo "Docker system disk usage:"
    sudo docker system df
    echo ""
    
    echo "Container resource usage:"
    sudo docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo ""
    
    # Log file check
    print_header "Log File Analysis"
    
    if [ -d "ragflow-logs" ]; then
        LOG_SIZE=$(du -sh ragflow-logs 2>/dev/null | cut -f1 || echo "Unknown")
        echo "RAGFlow logs directory size: $LOG_SIZE"
        
        # Check for recent errors in logs
        if find ragflow-logs -name "*.log" -mtime -1 -exec grep -l "ERROR\|FATAL" {} \; 2>/dev/null | head -5 | while read logfile; do
            echo "Recent errors found in: $logfile"
        done | grep -q "Recent errors"; then
            print_warning "Recent errors found in log files"
        else
            print_success "No recent errors found in log files"
        fi
    else
        print_warning "RAGFlow logs directory not found"
    fi
    
    # Network connectivity check
    print_header "Network Connectivity"
    
    # Check external connectivity
    if curl -s --connect-timeout 5 --max-time 10 "https://www.google.com" > /dev/null 2>&1; then
        print_success "External network connectivity is working"
    else
        print_warning "External network connectivity issues detected"
    fi
    
    # Summary
    print_header "Health Check Summary"
    
    if [ $FAILED_SERVICES -eq 0 ]; then
        print_success "All critical services are healthy! ✅"
        echo ""
        echo "RAGFlow is accessible at:"
        EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_VM_IP")
        echo "  🌐 http://$EXTERNAL_IP:$RAGFLOW_PORT"
        echo "  🌐 http://localhost:$RAGFLOW_PORT (if accessing locally)"
    else
        print_error "$FAILED_SERVICES service(s) are not healthy ❌"
        echo ""
        echo "Suggested actions:"
        echo "1. Check service logs: sudo docker compose logs"
        echo "2. Restart failed services: sudo docker compose restart"
        echo "3. Check system resources and free up space if needed"
        echo "4. Review recent configuration changes"
    fi
    
    echo ""
    echo "For detailed logs: sudo docker compose logs -f"
    echo "To restart services: sudo docker compose restart"
    echo "To view this status again: ./health-check.sh"
}

# Maintenance function
maintenance() {
    print_header "RAGFlow Maintenance Tasks"
    
    read -p "Perform maintenance tasks? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Maintenance cancelled."
        exit 0
    fi
    
    # Clean up old Docker resources
    print_status "Cleaning up old Docker resources..."
    sudo docker system prune -f
    
    # Rotate large log files
    print_status "Checking log file sizes..."
    if [ -d "ragflow-logs" ]; then
        find ragflow-logs -name "*.log" -size +100M -exec echo "Large log file found: {}" \;
    fi
    
    # Update system packages (optional)
    read -p "Update system packages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Updating system packages..."
        sudo apt-get update && sudo apt-get upgrade -y
    fi
    
    print_success "Maintenance tasks completed!"
}

# Check command line arguments
case "${1:-health}" in
    health|check)
        main
        ;;
    maintenance|maintain)
        maintenance
        ;;
    both)
        main
        echo ""
        maintenance
        ;;
    *)
        echo "Usage: $0 [health|maintenance|both]"
        echo "  health      - Run health checks (default)"
        echo "  maintenance - Run maintenance tasks"
        echo "  both        - Run both health checks and maintenance"
        exit 1
        ;;
esac
