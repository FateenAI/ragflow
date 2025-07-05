# RAGFlow Render Deployment Guide

This repository contains a Render Blueprint (`render.yaml`) for deploying RAGFlow, an open-source RAG (Retrieval-Augmented Generation) engine, on the Render platform.

## Overview

RAGFlow is a sophisticated AI application that provides document understanding and question-answering capabilities using Large Language Models (LLMs). This deployment configuration simplifies the process of running RAGFlow on Render's cloud infrastructure.

## Architecture

The Render Blueprint defines the following services:

### Core Services
- **Web Service (`ragflow-app`)**: Main application server running the RAGFlow API
- **Worker Service (`ragflow-worker`)**: Background worker for processing tasks
- **Redis**: Caching and session storage
- **PostgreSQL Database**: Primary data storage

### Service Plans
- **Web/Worker**: Pro plan (recommended for AI workloads)
- **Redis**: Standard plan
- **Database**: Standard plan

## Prerequisites

1. **Render Account**: Sign up at [render.com](https://render.com)
2. **GitHub Repository**: Fork or clone this RAGFlow repository
3. **Docker Knowledge**: Basic understanding of containerized applications

## Deployment Steps

### 1. Prepare Your Repository

Make sure your repository contains:
- The `render.yaml` blueprint file
- A proper `Dockerfile` for the RAGFlow application
- All source code and dependencies

### 2. Connect to Render

1. Log into your Render dashboard
2. Click "New +" and select "Blueprint"
3. Connect your GitHub repository containing the RAGFlow code
4. Select the repository and branch

### 3. Configure Environment Variables

The blueprint automatically configures most environment variables, but you may want to customize:

```yaml
# Key environment variables that are auto-configured:
- DATABASE_URL: PostgreSQL connection string
- REDIS_URL: Redis connection string
- TZ: Timezone (set to UTC)
- HF_ENDPOINT: Hugging Face mirror endpoint
- MEM_LIMIT: Memory limit for the application
```

### 4. Deploy

1. Review the blueprint configuration
2. Click "Create New Resources"
3. Monitor the deployment process in the Render dashboard

## Important Considerations

### Resource Requirements

RAGFlow is a resource-intensive AI application:
- **Memory**: Requires significant RAM for model loading and document processing
- **CPU**: Benefits from high-performance compute instances
- **Storage**: Needs persistent storage for logs and temporary files

### Limitations on Render

Some features from the original Docker Compose setup are not available on Render:

1. **Elasticsearch/OpenSearch**: Not included due to resource constraints
   - Consider using external search services like Algolia or AWS OpenSearch
2. **MinIO**: Replaced with external storage recommendations
   - Use Render's built-in static file serving or external S3-compatible storage
3. **Sandbox Execution**: Requires privileged containers not supported on Render
   - Code execution features may be limited

### Database Migration

The blueprint uses PostgreSQL instead of MySQL for better Render compatibility. You may need to:

1. Update database configuration in your application code
2. Modify any MySQL-specific queries to be PostgreSQL compatible
3. Update connection strings and drivers

## Configuration Details

### Web Service Configuration

```yaml
- type: web
  name: ragflow-app
  runtime: docker
  dockerfilePath: ./Dockerfile
  plan: pro
  disk:
    name: ragflow-storage
    mountPath: /ragflow/logs
    sizeGB: 20
```

### Database Configuration

```yaml
databases:
  - name: ragflow-db
    databaseName: ragflow
    user: ragflow
    plan: standard
```

### Redis Configuration

```yaml
- type: redis
  name: ragflow-redis
  plan: standard
  maxmemoryPolicy: allkeys-lru
```

## Customization Options

### Scaling

You can modify the blueprint to use different service plans:

```yaml
# For higher performance
plan: pro-plus  # or pro-max

# For development/testing
plan: starter
```

### Environment Variables

Add custom environment variables to the `envVars` section:

```yaml
envVars:
  - key: YOUR_CUSTOM_VAR
    value: "your-value"
  - key: SECRET_KEY
    generateValue: true  # Auto-generates secure value
```

### Additional Services

You can add external integrations:

```yaml
# Example: Add an external Elasticsearch service
envVars:
  - key: ELASTICSEARCH_URL
    value: "https://your-elasticsearch-provider.com"
```

## Monitoring and Maintenance

### Health Checks

Render automatically monitors your services. You can check:
- Service logs in the Render dashboard
- Resource usage metrics
- Application health status

### Scaling

Monitor your application performance and scale as needed:
- Upgrade service plans for more resources
- Add additional worker instances for background processing
- Scale database plan for larger datasets

## Troubleshooting

### Common Issues

1. **Memory Issues**: Upgrade to a higher plan with more RAM
2. **Build Failures**: Check Dockerfile and dependency installation
3. **Database Connection**: Verify environment variables are properly configured
4. **Performance**: Consider upgrading service plans or optimizing application code

### Logs and Debugging

Access logs through:
- Render Dashboard → Your Service → Logs
- Use `docker logs` commands during local development
- Check application-specific log files in `/ragflow/logs`

## External Dependencies

Since some services aren't available on Render, consider these alternatives:

### Search Engine
- **Algolia**: Managed search service
- **AWS OpenSearch**: Elasticsearch-compatible service
- **Typesense**: Open-source search engine with cloud hosting

### Object Storage
- **AWS S3**: Industry-standard object storage
- **Cloudinary**: Image and video management
- **Render Static Sites**: For serving static assets

### Vector Database
- **Pinecone**: Managed vector database
- **Weaviate**: Open-source vector database with cloud options
- **Qdrant**: Vector similarity search engine

## Cost Optimization

- Start with smaller plans and scale up as needed
- Use Redis for caching to reduce database load
- Optimize Docker images to reduce build times
- Monitor resource usage and adjust plans accordingly

## Security Considerations

- Use environment variables for sensitive configuration
- Enable Render's automatic HTTPS
- Regularly update dependencies and base images
- Consider using Render's private networking for service communication

## Support and Documentation

- [Render Documentation](https://render.com/docs)
- [RAGFlow Documentation](https://ragflow.io/docs)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## License

This deployment configuration is provided under the same license as RAGFlow. See the main project LICENSE file for details.
