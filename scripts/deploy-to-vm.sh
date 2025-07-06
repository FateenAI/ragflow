#!/bin/bash

# Quick deployment script to copy and run setup on GCP VM
# Usage: ./deploy-to-vm.sh [VM_NAME] [ZONE]

VM_NAME=${1:-ragflow-deployment}
ZONE=${2:-us-central1-a}
SCRIPT_PATH="scripts/setup-gcp-runner.sh"

echo "🚀 Deploying RAGFlow setup to GCP VM: $VM_NAME in zone: $ZONE"

# Check if the setup script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: $SCRIPT_PATH not found!"
    echo "Please run this script from the RAGFlow repository root."
    exit 1
fi

# Copy the setup script to the VM
echo "📁 Copying setup script to VM..."
gcloud compute scp "$SCRIPT_PATH" "$VM_NAME:~/" --zone="$ZONE"

# Copy Docker fix script if it exists
if [ -f "scripts/fix-docker.sh" ]; then
    echo "📁 Copying Docker fix script to VM..."
    gcloud compute scp "scripts/fix-docker.sh" "$VM_NAME:~/" --zone="$ZONE"
fi

# Copy Docker test script if it exists
if [ -f "scripts/test-fix-docker.sh" ]; then
    echo "📁 Copying Docker test script to VM..."
    gcloud compute scp "scripts/test-fix-docker.sh" "$VM_NAME:~/" --zone="$ZONE"
fi

# Copy complete Docker setup script if it exists
if [ -f "scripts/docker-complete-setup.sh" ]; then
    echo "📁 Copying complete Docker setup script to VM..."
    gcloud compute scp "scripts/docker-complete-setup.sh" "$VM_NAME:~/" --zone="$ZONE"
fi

# Copy Docker scripts help if it exists
if [ -f "scripts/docker-scripts-help.sh" ]; then
    echo "📁 Copying Docker scripts help to VM..."
    gcloud compute scp "scripts/docker-scripts-help.sh" "$VM_NAME:~/" --zone="$ZONE"
fi

if [ $? -eq 0 ]; then
    echo "✅ Setup script copied successfully!"
    echo "✅ Docker troubleshooting scripts also copied!"
    echo ""
    echo "🔗 Next steps:"
    echo "1. SSH into your VM:"
    echo "   gcloud compute ssh $VM_NAME --zone=$ZONE"
    echo ""
    echo "2a. EASIEST - Run complete Docker setup (install + test + fix):"
    echo "    chmod +x docker-complete-setup.sh && sudo ./docker-complete-setup.sh"
    echo ""
    echo "2b. OR run the full runner setup (includes Docker installation and testing):"
    echo "    chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh"
    echo ""
    echo "3. (Manual testing) Test Docker manually first:"
    echo "   chmod +x test-fix-docker.sh && ./test-fix-docker.sh"
    echo ""
    echo "4. (Manual fix) Run Docker fix if needed:"
    echo "   chmod +x fix-docker.sh && sudo ./fix-docker.sh"
    echo ""
    echo "🚀 QUICK START - Complete Docker setup:"
    echo "gcloud compute ssh $VM_NAME --zone=$ZONE --command='chmod +x docker-complete-setup.sh && sudo ./docker-complete-setup.sh'"
else
    echo "❌ Failed to copy script to VM. Please check:"
    echo "- VM name: $VM_NAME"
    echo "- Zone: $ZONE"
    echo "- VM is running and accessible"
fi
