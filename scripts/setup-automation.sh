#!/bin/bash

# Setup script for RAGFlow Render automation
# This script helps configure the repository for automated sync and deployment

set -e

echo "🚀 RAGFlow Render Automation Setup"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "This script must be run from within a git repository"
    exit 1
fi

# Check if this is a fork of infiniflow/ragflow
UPSTREAM_URL="https://github.com/infiniflow/ragflow.git"
CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

if [[ "$CURRENT_ORIGIN" == *"infiniflow/ragflow"* ]]; then
    print_warning "This appears to be the original repository, not a fork"
    echo "You should fork the repository first: https://github.com/infiniflow/ragflow/fork"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Setting up upstream remote"
echo "--------------------------------"

# Add upstream remote if it doesn't exist
if git remote get-url upstream >/dev/null 2>&1; then
    print_info "Upstream remote already exists"
    git remote set-url upstream "$UPSTREAM_URL"
    print_status "Updated upstream URL"
else
    git remote add upstream "$UPSTREAM_URL"
    print_status "Added upstream remote"
fi

# Fetch upstream
echo "Fetching upstream..."
git fetch upstream
git fetch upstream --tags
print_status "Fetched upstream changes and tags"

echo ""
echo "Step 2: Setting up deployment branch"
echo "-----------------------------------"

DEPLOY_BRANCH="features/deploy-render"

# Check if deployment branch exists
if git show-ref --verify --quiet refs/heads/$DEPLOY_BRANCH; then
    print_info "Deployment branch '$DEPLOY_BRANCH' already exists"
    git checkout $DEPLOY_BRANCH
else
    print_info "Creating deployment branch '$DEPLOY_BRANCH'"
    git checkout -b $DEPLOY_BRANCH
    print_status "Created and switched to deployment branch"
fi

# Ensure we have the latest changes
git merge upstream/main --no-edit 2>/dev/null || {
    print_warning "Merge conflicts detected - you may need to resolve them manually"
}

echo ""
echo "Step 3: Verifying required files"
echo "-------------------------------"

# Check for required files
REQUIRED_FILES=(
    ".github/workflows/sync-and-deploy.yml"
    "scripts/update-render-config.py"
    "render.yaml"
    "render-simple.yaml"
    "RENDER_DEPLOYMENT.md"
    "AUTOMATION_SETUP.md"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "$file exists"
    else
        print_error "$file is missing"
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo ""
    print_error "Some required files are missing. Please ensure all files are present:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo ""
echo "Step 4: Making scripts executable"
echo "-------------------------------"

chmod +x scripts/update-render-config.py
print_status "Made update-render-config.py executable"

echo ""
echo "Step 5: Testing configuration update script"
echo "------------------------------------------"

if python3 scripts/update-render-config.py --dry-run --check-docker; then
    print_status "Configuration update script works correctly"
else
    print_error "Configuration update script has issues"
    exit 1
fi

echo ""
echo "Step 6: Pushing deployment branch"
echo "--------------------------------"

read -p "Push the deployment branch to origin? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    print_info "Skipping push - remember to push manually later"
else
    if git push origin $DEPLOY_BRANCH; then
        print_status "Pushed deployment branch to origin"
    else
        print_warning "Failed to push - you may need to push manually"
    fi
fi

echo ""
echo "🎉 Setup Complete!"
echo "================="
echo ""
echo "Next steps:"
echo "1. Set up GitHub repository secrets:"
echo "   - RENDER_API_KEY: Get from https://dashboard.render.com/account/api-keys"
echo "   - RENDER_SERVICE_ID: Get from your Render service URL"
echo ""
echo "2. Deploy to Render using one of the blueprint files:"
echo "   - render.yaml (full configuration)"
echo "   - render-simple.yaml (minimal configuration)"
echo ""
echo "3. Enable the GitHub Actions workflow:"
echo "   - Go to your repository's Actions tab"
echo "   - Enable workflows if prompted"
echo ""
echo "4. Test the automation:"
echo "   - Trigger the workflow manually from GitHub Actions"
echo "   - Monitor the first run to ensure everything works"
echo ""
echo "📚 For detailed instructions, see AUTOMATION_SETUP.md"
echo "🚀 For deployment help, see RENDER_DEPLOYMENT.md"
echo ""

# Check if we're on the deployment branch
if [[ $(git branch --show-current) == "$DEPLOY_BRANCH" ]]; then
    print_status "You're ready to go! Current branch: $DEPLOY_BRANCH"
else
    print_info "Switch to the deployment branch: git checkout $DEPLOY_BRANCH"
fi
