#!/bin/bash

# Docker Volume and Log Cleanup Script for RAGFlow
# This script helps clean up Docker volumes, logs, and temporary files

set -e

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

# Change to docker directory
if [ ! -f "docker-compose.yml" ]; then
    if [ -d "docker" ] && [ -f "docker/docker-compose.yml" ]; then
        cd docker
        print_status "Changed to docker directory"
    else
        print_error "docker-compose.yml not found. Please run this script from the RAGFlow root or docker directory."
        exit 1
    fi
fi

print_header "RAGFlow Docker Cleanup Utility"

echo "This script helps you clean up Docker volumes, logs, and temporary files."
echo "WARNING: Some operations will permanently delete data!"
echo ""

# Show current disk usage
print_header "Current Disk Usage"

if command -v docker &> /dev/null; then
    echo "Docker system disk usage:"
    sudo docker system df 2>/dev/null || echo "Could not get Docker system info"
    echo ""
fi

if [ -d "ragflow-logs" ]; then
    LOG_SIZE=$(du -sh ragflow-logs 2>/dev/null | cut -f1 || echo "Unknown")
    echo "RAGFlow logs directory size: $LOG_SIZE"
else
    echo "RAGFlow logs directory: Not found"
fi

echo ""
echo "Local volume directories:"
for dir in ragflow-logs esdata01 osdata01 mysql_data redis_data minio_data infinity_data; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  $dir: $SIZE"
    else
        echo "  $dir: Not found"
    fi
done

echo ""

# Cleanup options
print_header "Cleanup Options"

echo "1. Clean Docker system (remove unused containers, networks, images)"
echo "2. Clean old log files (keep last 7 days)"
echo "3. Clean all RAGFlow logs"
echo "4. Remove all Docker volumes (WARNING: Will delete all data!)"
echo "5. Full cleanup (system + logs + stop services)"
echo "6. Just show status and exit"
echo ""

read -p "Select option (1-6): " OPTION

case $OPTION in
    1)
        print_header "Docker System Cleanup"
        print_warning "This will remove unused Docker containers, networks, and images"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleaning Docker system..."
            sudo docker system prune -f
            print_success "Docker system cleanup completed"
        else
            print_status "Cleanup cancelled"
        fi
        ;;
        
    2)
        print_header "Old Log File Cleanup"
        if [ -d "ragflow-logs" ]; then
            print_status "Cleaning log files older than 7 days..."
            find ragflow-logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
            find ragflow-logs -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
            print_success "Old log files cleaned"
        else
            print_warning "No ragflow-logs directory found"
        fi
        ;;
        
    3)
        print_header "All RAGFlow Logs Cleanup"
        if [ -d "ragflow-logs" ]; then
            LOG_SIZE=$(du -sh ragflow-logs 2>/dev/null | cut -f1 || echo "Unknown")
            print_warning "This will delete all RAGFlow logs (current size: $LOG_SIZE)"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Removing all RAGFlow logs..."
                rm -rf ragflow-logs/*
                print_success "All RAGFlow logs deleted"
            else
                print_status "Cleanup cancelled"
            fi
        else
            print_warning "No ragflow-logs directory found"
        fi
        ;;
        
    4)
        print_header "Docker Volumes Cleanup"
        print_error "WARNING: This will delete ALL persistent data including databases!"
        print_warning "This includes:"
        echo "  - Elasticsearch data"
        echo "  - MySQL databases" 
        echo "  - Redis data"
        echo "  - MinIO storage"
        echo "  - All application data"
        echo ""
        read -p "Are you ABSOLUTELY sure? Type 'DELETE' to confirm: " CONFIRMATION
        if [ "$CONFIRMATION" = "DELETE" ]; then
            print_status "Stopping all services..."
            sudo docker compose down -v --remove-orphans
            
            print_status "Removing Docker volumes..."
            sudo docker volume prune -f
            
            print_status "Removing local volume directories..."
            for dir in ragflow-logs esdata01 osdata01 mysql_data redis_data minio_data infinity_data; do
                if [ -d "$dir" ]; then
                    rm -rf "$dir"
                    print_status "Removed $dir"
                fi
            done
            
            print_success "All volumes and data deleted"
        else
            print_status "Cleanup cancelled - confirmation not received"
        fi
        ;;
        
    5)
        print_header "Full Cleanup"
        print_error "WARNING: This will stop services and clean everything!"
        read -p "Continue with full cleanup? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Stopping all services..."
            sudo docker compose down --remove-orphans
            
            print_status "Cleaning Docker system..."
            sudo docker system prune -f
            
            print_status "Cleaning old logs..."
            if [ -d "ragflow-logs" ]; then
                find ragflow-logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
            fi
            
            print_success "Full cleanup completed"
        else
            print_status "Cleanup cancelled"
        fi
        ;;
        
    6)
        print_status "Status check completed. No cleanup performed."
        ;;
        
    *)
        print_error "Invalid option selected"
        exit 1
        ;;
esac

# Final status
echo ""
print_header "Final Status"

if command -v docker &> /dev/null; then
    echo "Docker system disk usage after cleanup:"
    sudo docker system df 2>/dev/null || echo "Could not get Docker system info"
    echo ""
fi

echo "Current volume directories:"
for dir in ragflow-logs esdata01 osdata01 mysql_data redis_data minio_data infinity_data; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "  $dir: $SIZE"
    else
        echo "  $dir: Not found"
    fi
done

print_success "Cleanup utility completed! 🧹"
