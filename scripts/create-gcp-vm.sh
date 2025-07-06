#!/bin/bash

# GCP VM Creation Helper Script for RAGFlow Deployment
# This script helps generate the correct gcloud command with current images and your project details

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

print_header "RAGFlow GCP VM Creation Helper"

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$CURRENT_PROJECT" ]; then
    print_warning "No default project set in gcloud config"
    read -p "Enter your GCP Project ID: " PROJECT_ID
    gcloud config set project "$PROJECT_ID"
    CURRENT_PROJECT="$PROJECT_ID"
else
    print_status "Current project: $CURRENT_PROJECT"
    read -p "Use this project? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        read -p "Enter your GCP Project ID: " PROJECT_ID
        gcloud config set project "$PROJECT_ID"
        CURRENT_PROJECT="$PROJECT_ID"
    fi
fi

# Get available zones
print_status "Getting available zones..."
ZONES=$(gcloud compute zones list --filter="region:us-central1" --format="value(name)" | head -5)

echo "Available zones in us-central1:"
select ZONE in $ZONES "Other (specify)"; do
    if [ "$REPLY" -le $(echo "$ZONES" | wc -w) ] 2>/dev/null; then
        SELECTED_ZONE="$ZONE"
        break
    elif [ "$ZONE" = "Other (specify)" ]; then
        read -p "Enter zone (e.g., us-east1-b): " SELECTED_ZONE
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# Get VM specifications
print_status "VM Configuration"

echo "Recommended machine types for RAGFlow:"
echo "1. e2-standard-4 (4 vCPUs, 16GB RAM) - Minimum recommended"
echo "2. e2-standard-8 (8 vCPUs, 32GB RAM) - Better performance"  
echo "3. n1-standard-4 (4 vCPUs, 15GB RAM) - Alternative"
echo "4. Custom"

read -p "Select machine type (1-4) [1]: " MACHINE_CHOICE
MACHINE_CHOICE=${MACHINE_CHOICE:-1}

case $MACHINE_CHOICE in
    1) MACHINE_TYPE="e2-standard-4" ;;
    2) MACHINE_TYPE="e2-standard-8" ;;
    3) MACHINE_TYPE="n1-standard-4" ;;
    4) read -p "Enter custom machine type: " MACHINE_TYPE ;;
    *) MACHINE_TYPE="e2-standard-4" ;;
esac

read -p "Boot disk size in GB [50]: " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-50}

read -p "VM instance name [ragflow-deployment]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-ragflow-deployment}

# Get latest Ubuntu image
print_status "Getting latest Ubuntu 22.04 LTS image..."
LATEST_IMAGE=$(gcloud compute images list \
    --project=ubuntu-os-cloud \
    --filter="family:ubuntu-2204-lts AND architecture:X86_64" \
    --format="value(name)" \
    --sort-by="~creationTimestamp" \
    --limit=1)

if [ -z "$LATEST_IMAGE" ]; then
    print_warning "Could not fetch latest image, using image family"
    IMAGE_OPTION="--image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud"
else
    print_success "Latest Ubuntu 22.04 LTS image: $LATEST_IMAGE"
    IMAGE_OPTION="--image=$LATEST_IMAGE --image-project=ubuntu-os-cloud"
fi

# Check if default service account exists
SERVICE_ACCOUNT=$(gcloud iam service-accounts list --filter="email:$CURRENT_PROJECT-compute@developer.gserviceaccount.com" --format="value(email)" 2>/dev/null || echo "")

if [ -n "$SERVICE_ACCOUNT" ]; then
    print_status "Using default compute service account: $SERVICE_ACCOUNT"
    SA_OPTION="--service-account=$SERVICE_ACCOUNT"
else
    print_warning "Default compute service account not found"
    read -p "Enter service account email (or press Enter to skip): " CUSTOM_SA
    if [ -n "$CUSTOM_SA" ]; then
        SA_OPTION="--service-account=$CUSTOM_SA"
    else
        SA_OPTION=""
    fi
fi

# Generate the command
print_header "Generated GCP VM Creation Command"

cat << EOF

# Create RAGFlow deployment VM
gcloud compute instances create $INSTANCE_NAME \\
    --zone=$SELECTED_ZONE \\
    --machine-type=$MACHINE_TYPE \\
    $IMAGE_OPTION \\
    --boot-disk-size=${DISK_SIZE}GB \\
    --boot-disk-type=pd-standard \\
    --scopes=https://www.googleapis.com/auth/cloud-platform \\
    $SA_OPTION \\
    --labels=purpose=ragflow-deployment \\
    --tags=ragflow-deployment \\
    --metadata=enable-oslogin=true

EOF

# Generate firewall rules
print_header "Firewall Rules Command"

cat << EOF

# Create firewall rules for RAGFlow services
gcloud compute firewall-rules create ragflow-services \\
    --allow tcp:9380,tcp:80,tcp:443,tcp:1200,tcp:6601,tcp:22 \\
    --source-ranges 0.0.0.0/0 \\
    --target-tags ragflow-deployment \\
    --description "RAGFlow services ports"

EOF

# Ask if user wants to execute
echo ""
read -p "Do you want to execute these commands now? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Creating VM instance..."
    
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$SELECTED_ZONE \
        --machine-type=$MACHINE_TYPE \
        $IMAGE_OPTION \
        --boot-disk-size=${DISK_SIZE}GB \
        --boot-disk-type=pd-standard \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        $SA_OPTION \
        --labels=purpose=ragflow-deployment \
        --tags=ragflow-deployment \
        --metadata=enable-oslogin=true
    
    print_status "Creating firewall rules..."
    
    # Check if firewall rule already exists
    if gcloud compute firewall-rules describe ragflow-services &>/dev/null; then
        print_warning "Firewall rule 'ragflow-services' already exists. Skipping creation."
    else
        gcloud compute firewall-rules create ragflow-services \
            --allow tcp:9380,tcp:80,tcp:443,tcp:1200,tcp:6601,tcp:22 \
            --source-ranges 0.0.0.0/0 \
            --target-tags ragflow-deployment \
            --description "RAGFlow services ports"
    fi
    
    # Get external IP
    print_status "Getting VM details..."
    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$SELECTED_ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    
    print_success "VM created successfully!"
    echo ""
    echo "VM Details:"
    echo "  Name: $INSTANCE_NAME"
    echo "  Zone: $SELECTED_ZONE"
    echo "  Machine Type: $MACHINE_TYPE"
    echo "  External IP: $EXTERNAL_IP"
    echo ""
    print_header "Next Steps"
    echo "1. Copy setup script to VM (recommended):"
    echo "   ./scripts/deploy-to-vm.sh $INSTANCE_NAME $SELECTED_ZONE"
    echo ""
    echo "   OR manually:"
    echo "   gcloud compute scp scripts/setup-gcp-runner.sh $INSTANCE_NAME:~/ --zone=$SELECTED_ZONE"
    echo ""
    echo "2. SSH into your VM and run setup:"
    echo "   gcloud compute ssh $INSTANCE_NAME --zone=$SELECTED_ZONE"
    echo "   chmod +x setup-gcp-runner.sh"
    echo "   sudo ./setup-gcp-runner.sh"
    echo ""
    echo "   OR download from GitHub:"
    echo "   wget https://raw.githubusercontent.com/FateenAI/ragflow/develop/scripts/setup-gcp-runner.sh"
    echo ""
    echo "3. After deployment, access RAGFlow at:"
    echo "   http://$EXTERNAL_IP:9380"
    
else
    print_status "Commands saved. You can copy and run them manually."
    echo ""
    print_header "Next Steps"
    echo "1. Copy and run the VM creation command above"
    echo "2. Copy and run the firewall rules command above"
    echo "3. Copy setup script to VM:"
    echo "   ./scripts/deploy-to-vm.sh $INSTANCE_NAME $SELECTED_ZONE"
    echo "4. SSH into your VM and run the setup script"
fi

print_success "Setup complete! 🎉"
