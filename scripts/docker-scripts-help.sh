#!/bin/bash

# Docker Scripts Summary - Shows all available Docker troubleshooting tools
# This is a quick reference for all Docker-related scripts

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🐳 RAGFlow Docker Scripts Summary"
echo "=================================="
echo ""

echo -e "${BLUE}Available Docker Scripts:${NC}"
echo ""

echo -e "${GREEN}1. docker-complete-setup.sh${NC} (RECOMMENDED)"
echo "   • Complete Docker installation, testing, and fixing"
echo "   • Usage: sudo ./docker-complete-setup.sh"
echo "   • Best for: First-time setup or complete Docker refresh"
echo ""

echo -e "${GREEN}2. test-fix-docker.sh${NC}"
echo "   • Safe demonstration of the fix process (no changes)"
echo "   • Usage: ./test-fix-docker.sh"
echo "   • Best for: Understanding what fixes would be applied"
echo ""

echo -e "${GREEN}3. fix-docker.sh${NC}"
echo "   • Progressive Docker repair tool (5 levels of fixes)"
echo "   • Usage: sudo ./fix-docker.sh"
echo "   • Best for: When Docker is installed but not working"
echo ""

echo -e "${GREEN}4. setup-gcp-runner.sh${NC}"
echo "   • Full GitHub runner setup (includes Docker)"
echo "   • Usage: sudo ./setup-gcp-runner.sh"
echo "   • Best for: Complete RAGFlow deployment setup"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo ""

echo "Test if Docker is working:"
echo "  docker --version && docker run --rm hello-world"
echo ""

echo "Check Docker service status:"
echo "  sudo systemctl status docker"
echo ""

echo "View Docker logs:"
echo "  sudo journalctl -u docker.service -f"
echo ""

echo "Add user to docker group (to avoid sudo):"
echo "  sudo usermod -aG docker \$USER && newgrp docker"
echo ""

echo -e "${BLUE}Script Locations:${NC}"
echo ""

for script in docker-complete-setup.sh test-fix-docker.sh fix-docker.sh setup-gcp-runner.sh; do
    if [ -f "./$script" ]; then
        echo -e "  ✅ ${GREEN}$script${NC} - Available in current directory"
    elif [ -f "./scripts/$script" ]; then
        echo -e "  ✅ ${GREEN}scripts/$script${NC} - Available in scripts directory"
    else
        echo -e "  ❌ ${YELLOW}$script${NC} - Not found"
    fi
done

echo ""
echo -e "${BLUE}Recommended Workflow:${NC}"
echo "1. Run: sudo ./docker-complete-setup.sh"
echo "2. Add user to docker group: sudo usermod -aG docker \$USER"
echo "3. Test: docker run hello-world"
echo "4. If issues persist: sudo ./fix-docker.sh"
echo ""

echo "For complete RAGFlow setup: sudo ./setup-gcp-runner.sh"
echo ""
