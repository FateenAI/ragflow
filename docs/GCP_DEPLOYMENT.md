# RAGFlow GCP Deployment Guide

## 🚀 TL;DR - Fastest Setup (5 minutes)

```bash
# 1. Create VM with automated helper
./scripts/create-gcp-vm.sh

# 2. Copy and run setup script  
./scripts/deploy-to-vm.sh ragflow-deployment us-central1-a
gcloud compute ssh ragflow-deployment --zone=us-central1-a
chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh

# 3. Configure runner (interactive)
sudo su - runner
cd /home/runner/actions-runner
./configure-runner.sh
sudo systemctl start github-runner

# 4. Set GitHub secrets/variables (see below)
# 5. Deploy via GitHub Actions
```

**That's it!** ✅ RAGFlow will be running at `http://YOUR_VM_IP:9380`

---

This guide explains how to set up automated deployment of RAGFlow to a GCP VM using GitHub Actions with a self-hosted runner.

## Prerequisites

1. **GCP VM Requirements:**
   - Ubuntu 20.04 LTS or 22.04 LTS
   - Minimum 4 CPU cores, 8GB RAM
   - At least 50GB disk space
   - External IP address
   - Firewall rules allowing inbound traffic on required ports

2. **GitHub Repository:**
   - Fork of the RAGFlow repository
   - Admin access to configure secrets and variables

## Setup Instructions

### 🚀 Quick Start (Easiest Method)

**1. Create VM with automated helper:**
```bash
# Download and run the VM creation helper
./scripts/create-gcp-vm.sh
```

This interactive script will:
- ✅ Detect your GCP project and settings
- ✅ Show available zones and machine types
- ✅ Use the latest Ubuntu 22.04 LTS image
- ✅ Create firewall rules automatically
- ✅ Provide ready-to-copy commands

**2. Deploy the runner setup:**
```bash
# Copy and run the setup script (after VM creation)
./scripts/deploy-to-vm.sh ragflow-deployment us-central1-a
```

**3. Configure the runner:**
```bash
# SSH into your VM and complete setup
gcloud compute ssh ragflow-deployment --zone=us-central1-a
chmod +x setup-gcp-runner.sh
sudo ./setup-gcp-runner.sh
```

### 📋 Alternative: Manual Method

If you prefer manual control, follow these steps:

**1. Create a VM instance:**
```bash
# Simplified command (recommended)
gcloud compute instances create ragflow-deployment \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-standard \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --labels=purpose=ragflow-deployment \
  --tags=ragflow-deployment
```

**2. Configure firewall rules:**
```bash
# Create firewall rules for RAGFlow services
gcloud compute firewall-rules create ragflow-services \
  --allow tcp:9380,tcp:80,tcp:443,tcp:1200,tcp:6601,tcp:22 \
  --source-ranges 0.0.0.0/0 \
  --target-tags ragflow-deployment \
  --description "RAGFlow services ports"
```

### 2. Set Up the Self-Hosted Runner

**Option A: Copy from local repository (fastest):**
```bash
# Copy the setup script to your VM
gcloud compute scp scripts/setup-gcp-runner.sh ragflow-deployment:~/ --zone=us-central1-a

# SSH and run setup
gcloud compute ssh ragflow-deployment --zone=us-central1-a
chmod +x setup-gcp-runner.sh
sudo ./setup-gcp-runner.sh
```

**Option B: Download from GitHub:**
```bash
# SSH into your GCP VM
gcloud compute ssh ragflow-deployment --zone=us-central1-a

# Download and run the setup script
wget https://raw.githubusercontent.com/FateenAI/ragflow/develop/scripts/setup-gcp-runner.sh
chmod +x setup-gcp-runner.sh
sudo ./setup-gcp-runner.sh
```

3. **Configure the GitHub Actions runner:**
   ```bash
   # Switch to runner user
   sudo su - runner
   
   # Run the configuration script
   cd /home/runner/actions-runner
   ./configure-runner.sh
   ```

   When prompted, provide:
   - **Repository URL**: `https://github.com/FateenAI/ragflow`
   - **Registration Token**: Get this from your GitHub repository settings → Actions → Runners → "New self-hosted runner"
   - **Runner Name**: `ragflow-gcp-runner` (or your preferred name)
   - **Labels**: `self-hosted,linux,ragflow-gcp`

4. **Start the runner service:**
   ```bash
   sudo systemctl start github-runner
   sudo systemctl status github-runner
   ```

### 🎯 Complete Setup in 3 Commands

For the absolute fastest setup, run these three commands:

```bash
# 1. Create VM with helper script
./scripts/create-gcp-vm.sh

# 2. Copy and run setup (replace VM_NAME and ZONE if different)
./scripts/deploy-to-vm.sh ragflow-deployment us-central1-a && \
gcloud compute ssh ragflow-deployment --zone=us-central1-a --command='chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh'

# 3. Configure runner (requires interactive input)
gcloud compute ssh ragflow-deployment --zone=us-central1-a
sudo su - runner
cd /home/runner/actions-runner
./configure-runner.sh
sudo systemctl start github-runner
```

### 3. Configure GitHub Repository Secrets

Navigate to your GitHub repository settings → Secrets and variables → Actions, and add the following secrets:

#### Required Secrets:

```yaml
# Database Passwords
ELASTIC_PASSWORD: "your_secure_elasticsearch_password"
OPENSEARCH_PASSWORD: "your_secure_opensearch_password_OS_01"
MYSQL_PASSWORD: "your_secure_mysql_password"
REDIS_PASSWORD: "your_secure_redis_password"
KIBANA_PASSWORD: "your_secure_kibana_password"

# AI Service API Keys (add the ones you plan to use)
OPENAI_API_KEY: "sk-your_openai_api_key"
AZURE_OPENAI_API_KEY: "your_azure_openai_key"
GEMINI_API_KEY: "your_gemini_api_key"
ANTHROPIC_API_KEY: "your_anthropic_api_key"

# Optional: Additional AI Services
DASHSCOPE_API_KEY: "your_dashscope_key"
MOONSHOT_API_KEY: "your_moonshot_key"
ZHIPUAI_API_KEY: "your_zhipuai_key"
OLLAMA_API_KEY: "your_ollama_key"
```

#### Security Best Practices for Passwords:
- Use strong passwords with at least 12 characters
- Include uppercase, lowercase, numbers, and special characters
- For OpenSearch password, ensure it meets the requirement: at least one uppercase letter, one lowercase letter, one digit, and one special character

### 4. Configure GitHub Repository Variables

Navigate to your GitHub repository settings → Secrets and variables → Actions → Variables tab, and add the following variables:

#### Core Configuration Variables:

```yaml
# Document Engine Configuration
DOC_ENGINE: "elasticsearch"  # Options: elasticsearch, opensearch, infinity

# RAGFlow Image Configuration
RAGFLOW_IMAGE: "infiniflow/ragflow:v0.17.0"  # Update to latest version as needed

# Service Ports
SVR_HTTP_PORT: "9380"        # RAGFlow main service port
ES_PORT: "1200"              # Elasticsearch port
KIBANA_PORT: "6601"          # Kibana port
OS_PORT: "1201"              # OpenSearch port
MYSQL_PORT: "5455"           # MySQL port

# Service Hostnames
ES_HOST: "es01"
OS_HOST: "opensearch01"
MYSQL_HOST: "mysql"
REDIS_HOST: "redis"
INFINITY_HOST: "infinity"

# Database Configuration
MYSQL_USER: "root"
MYSQL_DATABASE: "rag_flow"
KIBANA_USER: "rag_flow"

# System Configuration
MEM_LIMIT: "8073741824"      # 8GB in bytes - adjust based on your VM specs
TIMEZONE: "UTC"              # Or your preferred timezone like "America/New_York"
STACK_VERSION: "8.11.3"     # Elasticsearch version

# Hugging Face Configuration
HF_ENDPOINT: "https://huggingface.co"

# Additional Ports (if needed)
INFINITY_PORT: "23817"
REDIS_PORT: "6379"
```

#### Memory Configuration Guidelines:
Based on your VM specifications:
- **4GB VM**: Set `MEM_LIMIT` to `3221225472` (3GB)
- **8GB VM**: Set `MEM_LIMIT` to `6442450944` (6GB) 
- **16GB VM**: Set `MEM_LIMIT` to `12884901888` (12GB)

### 5. Test the Deployment

1. **Trigger a manual deployment:**
   - Go to your repository → Actions
   - Select "Deploy RAGFlow to GCP VM" workflow
   - Click "Run workflow"
   - Optionally check "Force rebuild Docker images" for the first run

2. **Monitor the deployment:**
   - Watch the workflow execution in the Actions tab
   - SSH into your VM to check services: `sudo su - runner && ./monitor-ragflow.sh`

3. **Access RAGFlow:**
   - Open your browser and navigate to: `http://YOUR_VM_EXTERNAL_IP:9380`
   - The default admin credentials should be configured during first setup

### 6. Monitoring and Maintenance

#### Useful Commands on the VM:

```bash
# Switch to runner user
sudo su - runner

# Check RAGFlow service status
./monitor-ragflow.sh

# View service logs
ragflow-logs

# Restart services
ragflow-restart

# Stop services
ragflow-stop

# Start services
ragflow-start

# Check runner service status
sudo systemctl status github-runner
```

#### Log Locations:

- **GitHub Runner logs**: `journalctl -u github-runner -f`
- **RAGFlow service logs**: `~/actions-runner/_work/*/ragflow/docker/ragflow-logs/`
- **Docker logs**: `sudo docker compose logs` (from the docker directory)

### 7. Firewall Configuration

The setup script includes a firewall configuration script. Run it to secure your VM:

```bash
sudo /root/configure-firewall.sh
```

This will:
- Allow SSH (port 22)
- Allow RAGFlow services (ports 9380, 80, 443)
- Allow Elasticsearch (port 1200)
- Allow Kibana (port 6601)
- Allow OpenSearch (port 1201, if used)
- Deny all other incoming traffic

### 8. Backup and Recovery

#### Important directories to backup:
- `/home/runner/actions-runner/_work/*/ragflow/docker/ragflow-logs/`
- Database volumes (automatically managed by Docker)
- Configuration files in the docker directory

#### Recovery procedure:
1. Ensure the VM is running and accessible
2. Restart the GitHub runner service: `sudo systemctl restart github-runner`
3. Trigger a new deployment from GitHub Actions
4. The workflow will automatically pull the latest code and restart services

### 9. Troubleshooting

#### Common Issues:

1. **Runner not appearing in GitHub:**
   - Check runner service: `sudo systemctl status github-runner`
   - Restart runner: `sudo systemctl restart github-runner`
   - Check logs: `journalctl -u github-runner -f`

2. **Docker permission issues:**
   - Ensure runner user is in docker group: `sudo usermod -aG docker runner`
   - Restart the session or reboot the VM

3. **Services not starting:**
   - Check VM resources: `free -h` and `df -h`
   - Review Docker logs: `sudo docker compose logs`
   - Increase memory limits if necessary

4. **Port conflicts:**
   - Check if ports are already in use: `sudo netstat -tlnp`
   - Modify port variables in GitHub repository settings

5. **Network connectivity issues:**
   - Verify firewall rules: `sudo ufw status`
   - Check GCP firewall settings in the console

#### Common GCP Command Issues:

1. **Image not found error:**
   ```bash
   # Use the latest image automatically
   gcloud compute instances create ragflow-deployment \
     --zone=us-central1-a \
     --machine-type=e2-standard-4 \
     --image-family=ubuntu-2204-lts \
     --image-project=ubuntu-os-cloud \
     --boot-disk-size=50GB
   ```

2. **Project not specified:**
   ```bash
   # Set your default project
   gcloud config set project YOUR_PROJECT_ID
   ```

3. **Insufficient permissions:**
   ```bash
   # Ensure you have the necessary roles
   gcloud auth list
   gcloud auth application-default login
   ```

4. **Zone not available:**
   ```bash
   # List available zones
   gcloud compute zones list --filter="region:us-central1"
   ```

5. **Service account not found:**
   ```bash
   # List service accounts
   gcloud iam service-accounts list
   # Or omit the service account parameter to use default
   ```

#### Getting Help:

- **Use the helper scripts**: `./scripts/create-gcp-vm.sh` for VM creation, `./health-check.sh` for monitoring
- **Check workflow logs** in GitHub Actions
- **SSH into the VM** and run `./monitor-ragflow.sh` or `ragflow-logs`
- **Review service logs** with `sudo docker compose logs`
- **Check system resources** with `free -h` and `df -h`
- **Verify runner status** with `sudo systemctl status github-runner`

## Security Considerations

1. **Keep secrets secure**: Never commit API keys or passwords to the repository
2. **Regular updates**: Keep the VM and Docker images updated
3. **Firewall**: Only open necessary ports
4. **Monitoring**: Set up alerts for service failures
5. **Backup**: Regularly backup important data and configurations

## Cost Optimization

1. **VM sizing**: Start with smaller VMs and scale up as needed
2. **Preemptible instances**: Consider using preemptible VMs for development
3. **Automatic shutdown**: Set up schedules to stop VMs when not in use
4. **Storage optimization**: Clean up old Docker images and logs regularly

The setup is now complete! Your RAGFlow deployment will automatically update whenever you push changes to the configured branches.

### Important Notes:

#### Docker Volume Management
The deployment automatically creates Docker volumes for persistent data storage. These directories are automatically ignored by Git:

- `docker/ragflow-logs/` - Application logs
- `docker/esdata01/` - Elasticsearch data
- `docker/osdata01/` - OpenSearch data  
- `docker/mysql_data/` - MySQL database data
- `docker/redis_data/` - Redis data
- `docker/minio_data/` - MinIO object storage
- `docker/infinity_data/` - Infinity vector database

**Never commit these directories** as they contain:
- Sensitive database data
- Large volume mounts
- Runtime logs and temporary files

The `.gitignore` files are already configured to exclude these directories.

## 📋 Script Reference

The repository includes several helper scripts to automate the deployment:

| Script | Purpose | Usage |
|--------|---------|--------|
| `create-gcp-vm.sh` | Interactive VM creation | `./scripts/create-gcp-vm.sh` |
| `deploy-to-vm.sh` | Copy setup script to VM | `./scripts/deploy-to-vm.sh VM_NAME ZONE` |
| `setup-gcp-runner.sh` | Install Docker & GitHub runner | `sudo ./setup-gcp-runner.sh` (on VM) |
| `health-check.sh` | Monitor services & system | `./health-check.sh` (on VM) |
| `cleanup-docker.sh` | Clean volumes & logs | `./cleanup-docker.sh` (on VM) |

**Pro tip:** Use the `create-gcp-vm.sh` script first - it autodetects your GCP settings and provides ready-to-copy commands! 🎯
