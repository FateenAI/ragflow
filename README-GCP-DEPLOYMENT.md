# RA## 🚀 Quick Start

### 1. VM Setup (2 minutes)

**Automated VM creation (Recommended):**
```bash
# Interactive VM creation with latest Ubuntu image
./scripts/create-gcp-vm.sh
`| 16GB | 24GB | `25769803776` |

## 🐳 **Docker Troubleshooting**

The deployment includes comprehensive Docker troubleshooting tools:

### Available Scripts:

1. **`docker-complete-setup.sh`** - Complete Docker installation, testing, and fixing (RECOMMENDED)
   ```bash
   sudo ./docker-complete-setup.sh
   ```

2. **`test-fix-docker.sh`** - Safe demonstration of the fix process (no changes made)
   ```bash
   ./test-fix-docker.sh
   ```

3. **`fix-docker.sh`** - Progressive Docker repair tool with 5 levels of fixes
   ```bash
   sudo ./fix-docker.sh
   ```

### What the Fix Script Does:

- **Level 1**: Minimal Docker configuration (overlay2 storage)
- **Level 2**: Clean restart (removes custom config)
- **Level 3**: VFS storage driver (more compatible but slower)
- **Level 4**: Complete Docker data reset
- **Level 5**: Full Docker reinstall

### Common Docker Issues Fixed:

- ✅ Permission denied errors (docker group membership)
- ✅ Docker daemon startup failures
- ✅ Storage driver conflicts
- ✅ Network initialization errors
- ✅ Container execution problems
- ✅ Memory and disk space issues

### Manual Docker Troubleshooting:

```bash
# Check Docker status
sudo systemctl status docker

# View Docker logs
sudo journalctl -u docker.service -f

# Test Docker functionality
docker run hello-world

# Check Docker system info
docker system info
```

## 📁 **Git Configuration**

The repository is pre-configured to ignore Docker volume directories and sensitive files:

```bash
# These directories are automatically ignored:
docker/ragflow-logs/          # Application logs
docker/esdata01/             # Elasticsearch data
docker/mysql_data/           # MySQL data
docker/redis_data/           # Redis data
docker/.env                  # Environment variables
```

Use the cleanup script to manage disk space:
```bash
./scripts/cleanup-docker.sh
```ation:**
```bash
gcloud compute instances create ragflow-deployment \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --tags=ragflow-deployment

# Create firewall rules
gcloud compute firewall-rules create ragflow-services \
  --allow tcp:9380,tcp:80,tcp:443,tcp:1200,tcp:6601,tcp:22 \
  --target-tags ragflow-deployment
```

### 2. Runner Setup (3 minutes)

**Option A: Copy all scripts and use complete Docker setup (EASIEST):**
```bash
# Copy all scripts to VM
./scripts/deploy-to-vm.sh ragflow-deployment us-central1-a

# SSH and run complete Docker setup (install + test + fix)
gcloud compute ssh ragflow-deployment --zone=us-central1-a
chmod +x docker-complete-setup.sh && sudo ./docker-complete-setup.sh

# Then run the runner setup
chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh
```

**Option B: One-command Docker setup from VM:**
```bash
gcloud compute ssh ragflow-deployment --zone=us-central1-a --command='chmod +x docker-complete-setup.sh && sudo ./docker-complete-setup.sh'
```

**Option C: Traditional full runner setup:**
```bash
./scripts/deploy-to-vm.sh ragflow-deployment us-central1-a
gcloud compute ssh ragflow-deployment --zone=us-central1-a
chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh
```

**Option D: Download from GitHub:**
```bash
gcloud compute ssh ragflow-deployment --zone=us-central1-a
wget https://raw.githubusercontent.com/FateenAI/ragflow/develop/scripts/setup-gcp-runner.sh
chmod +x setup-gcp-runner.sh && sudo ./setup-gcp-runner.sh
```t - Quick Start

This repository contains automated deployment configurations for RAGFlow on Google Cloud Platform (GCP) using GitHub Actions and self-hosted runners.

## 🚀 Quick Start

### 1. VM Setup (5 minutes)

**Option A: Use the automated VM creation script (Recommended):**
```bash
# Download and run the VM creation helper
wget https://raw.githubusercontent.com/FateenAI/ragflow/develop/scripts/create-gcp-vm.sh
chmod +x create-gcp-vm.sh
./create-gcp-vm.sh
```

**Option B: Manual VM creation:**
```bash
# On your GCP VM (Ubuntu 20.04/22.04):
wget https://raw.githubusercontent.com/FateenAI/ragflow/develop/scripts/setup-gcp-runner.sh
chmod +x setup-gcp-runner.sh
sudo ./setup-gcp-runner.sh
```

### 3. Runner Configuration (2 minutes)
```bash
# Configure GitHub Actions runner
sudo su - runner
cd /home/runner/actions-runner
./configure-runner.sh

# Start the runner service
sudo systemctl start github-runner
sudo systemctl status github-runner
```

### 4. GitHub Secrets Configuration

Add these **Secrets** in your GitHub repository (Settings → Secrets and variables → Actions):

```yaml
# Required Passwords (use strong passwords!)
ELASTIC_PASSWORD: "your_secure_elasticsearch_password"
MYSQL_PASSWORD: "your_secure_mysql_password"
REDIS_PASSWORD: "your_secure_redis_password"

# AI API Keys (add the ones you plan to use)
OPENAI_API_KEY: "sk-your_openai_api_key"
AZURE_OPENAI_API_KEY: "your_azure_openai_key"
GEMINI_API_KEY: "your_gemini_api_key"
ANTHROPIC_API_KEY: "your_anthropic_api_key"
```

### 5. GitHub Variables Configuration

Add these **Variables** in your GitHub repository (Settings → Secrets and variables → Actions → Variables):

```yaml
# Core Configuration
DOC_ENGINE: "elasticsearch"
RAGFLOW_IMAGE: "infiniflow/ragflow:v0.17.0"
SVR_HTTP_PORT: "9380"
MEM_LIMIT: "6442450944"  # 6GB for 8GB VM
TIMEZONE: "UTC"
```

### 6. Deploy RAGFlow
- Go to your repository → Actions
- Select "Deploy RAGFlow to GCP VM"
- Click "Run workflow"

🎉 **That's it!** RAGFlow will be available at `http://YOUR_VM_IP:9380`

## 📋 Requirements

### GCP VM Specifications
- **Minimum**: 4 CPU cores, 8GB RAM, 50GB disk
- **Recommended**: 8 CPU cores, 16GB RAM, 100GB disk
- **OS**: Ubuntu 20.04 LTS or 22.04 LTS
- **Network**: External IP with firewall rules for ports 22, 80, 443, 9380, 1200, 6601

### Required GCP Firewall Rules
```bash
gcloud compute firewall-rules create ragflow-services \
  --allow tcp:9380,tcp:80,tcp:443,tcp:1200,tcp:6601,tcp:22 \
  --source-ranges 0.0.0.0/0 \
  --description "RAGFlow services ports"
```

## 🔧 Configuration Details

### Complete Secrets List
| Secret Name | Description | Required | Example |
|-------------|-------------|----------|---------|
| `ELASTIC_PASSWORD` | Elasticsearch password | Yes | `secure_password_123!` |
| `MYSQL_PASSWORD` | MySQL root password | Yes | `mysql_secure_pass_456!` |
| `REDIS_PASSWORD` | Redis password | Yes | `redis_pass_789!` |
| `KIBANA_PASSWORD` | Kibana password | No | `kibana_pass_abc!` |
| `OPENSEARCH_PASSWORD` | OpenSearch password (if using OpenSearch) | No | `OS_pass_123!` |
| `OPENAI_API_KEY` | OpenAI API key | No | `sk-...` |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI key | No | `...` |
| `GEMINI_API_KEY` | Google Gemini API key | No | `...` |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key | No | `...` |

### Complete Variables List
| Variable Name | Description | Default | Options |
|---------------|-------------|---------|---------|
| `DOC_ENGINE` | Document engine to use | `elasticsearch` | `elasticsearch`, `opensearch`, `infinity` |
| `RAGFLOW_IMAGE` | Docker image version | `infiniflow/ragflow:v0.17.0` | Any valid tag |
| `SVR_HTTP_PORT` | RAGFlow service port | `9380` | Any available port |
| `ES_PORT` | Elasticsearch port | `1200` | Any available port |
| `KIBANA_PORT` | Kibana port | `6601` | Any available port |
| `MYSQL_PORT` | MySQL port | `5455` | Any available port |
| `MEM_LIMIT` | Memory limit in bytes | `8073741824` (8GB) | Based on VM specs |
| `TIMEZONE` | System timezone | `UTC` | Any valid timezone |

### Memory Configuration by VM Size
| VM RAM | Recommended MEM_LIMIT | Value in Bytes |
|--------|----------------------|----------------|
| 4GB | 3GB | `3221225472` |
| 8GB | 6GB | `6442450944` |
| 16GB | 12GB | `12884901888` |
| 32GB | 24GB | `25769803776` |

## 📁 **Git Configuration**

The repository is pre-configured to ignore Docker volume directories and sensitive files:

```bash
# These directories are automatically ignored:
docker/ragflow-logs/          # Application logs
docker/esdata01/             # Elasticsearch data
docker/mysql_data/           # MySQL data
docker/redis_data/           # Redis data
docker/.env                  # Environment variables
```

Use the cleanup script to manage disk space:
```bash
./scripts/cleanup-docker.sh
```

## 🔍 Monitoring & Maintenance

### Health Check
```bash
# SSH into your VM
sudo su - runner
./monitor-ragflow.sh
```

### View Logs
```bash
# Service logs
ragflow-logs

# Runner logs
sudo journalctl -u github-runner -f
```

### Restart Services
```bash
ragflow-restart  # Restart all services
ragflow-stop     # Stop all services
ragflow-start    # Start all services
```

### System Maintenance
```bash
# Run comprehensive health check and maintenance
./health-check.sh both
```

## 🌐 Access URLs

After successful deployment:
- **RAGFlow UI**: `http://YOUR_VM_IP:9380`
- **Elasticsearch**: `http://YOUR_VM_IP:1200`
- **Kibana**: `http://YOUR_VM_IP:6601`

## 🔒 Security Best Practices

1. **Strong Passwords**: Use complex passwords for all services
2. **Firewall**: Only open necessary ports
3. **Updates**: Keep VM and containers updated
4. **Monitoring**: Set up alerts for service failures
5. **Backup**: Regular backup of important data

## 🛠️ Troubleshooting

### Common Issues

#### Runner Not Showing in GitHub
```bash
sudo systemctl restart github-runner
sudo journalctl -u github-runner -f
```

#### Services Not Starting
```bash
# Check resources
free -h
df -h

# Check Docker
sudo docker compose logs

# Restart Docker
sudo systemctl restart docker
```

#### Port Conflicts
```bash
# Check what's using ports
sudo netstat -tlnp | grep :9380
```

### Get Help
1. Check the [detailed deployment guide](docs/GCP_DEPLOYMENT.md)
2. Review workflow logs in GitHub Actions
3. Run health checks: `./health-check.sh`
4. Check service logs: `ragflow-logs`

## 📚 Additional Documentation

- [Complete GCP Deployment Guide](docs/GCP_DEPLOYMENT.md) - Detailed setup instructions
- [RAGFlow Documentation](README.md) - Main project documentation
- [Docker Configuration](docker/README.md) - Docker-specific setup

## 🔄 Automatic Updates

The deployment automatically updates when you:
- Push to `main`, `features/deploy-render`, or `develop` branches
- Create pull requests to `main`
- Manually trigger the workflow

## 💰 Cost Optimization

- **VM Sizing**: Start with e2-standard-4, scale as needed
- **Preemptible**: Use preemptible instances for development
- **Scheduling**: Set up automatic shutdown during off-hours
- **Cleanup**: Regular cleanup of old Docker images and logs

---

**Need help?** Check the troubleshooting section above or create an issue in this repository.
