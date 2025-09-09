# WebStar Server Deployment Guide

Deploy your WebStar server to any cloud platform using Docker and automated GitHub Actions.

## Table of Contents
- [Quick Start](#quick-start)
- [Automated Deployment](#automated-deployment)
- [Platform-Specific Instructions](#platform-specific-instructions)
- [Local Development](#local-development)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)

---

## Quick Start

**WebStar works with ANY cloud provider that supports Docker:**

```bash
# Works everywhere Docker runs
docker run -d --name webstar-server -p 80:5090 --restart unless-stopped \
  ghcr.io/santasliar/webstar-server:latest
```

**Supported Platforms:**
- ✅ DigitalOcean, AWS, Google Cloud, Azure
- ✅ Heroku, Railway, Render, Fly.io  
- ✅ Any Linux server with Docker
- ✅ Kubernetes clusters

---

## Automated Deployment

### GitHub Actions Setup

1. **Configure GitHub Secrets** (for any Linux server):
   ```
   DO_HOST = your-server-ip (any provider)
   DO_USERNAME = ssh-username (usually 'root' or 'ubuntu')
   DO_PRIVATE_KEY = your-ssh-private-key
   ```

2. **Push to main branch** → Automatic deployment!
   - Builds Docker image
   - Pushes to GitHub Container Registry
   - Deploys to your server via SSH

3. **Access your server**: `http://your-server-ip/health`

### Server Prerequisites

Install Docker on any Linux server (works with all cloud providers):
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

---

## Platform-Specific Instructions

### Traditional Servers (DigitalOcean, AWS EC2, Google Compute, Azure VM)

<details>
<summary>Click to expand server deployment instructions</summary>

**Same setup works for all providers:**

```bash
# 1. Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Configure GitHub Actions with your server details
# 3. Push to main branch - auto-deployment!

# Manual deployment alternative:
docker pull ghcr.io/santasliar/webstar-server:latest
docker run -d --name webstar-server -p 80:5090 --restart unless-stopped \
  ghcr.io/santasliar/webstar-server:latest
```

**Firewall Ports:**
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS, if using SSL)

</details>

### AWS Services

<details>
<summary>Click to expand AWS deployment options</summary>

#### AWS Fargate (ECS)
```json
{
  "family": "webstar-server",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [{
    "name": "webstar-server",
    "image": "ghcr.io/santasliar/webstar-server:latest",
    "portMappings": [{"containerPort": 5090, "protocol": "tcp"}],
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:5090/health || exit 1"]
    }
  }]
}
```

#### AWS App Runner
```bash
# Deploy directly from container registry
aws apprunner create-service \
  --service-name webstar-server \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "ghcr.io/santasliar/webstar-server:latest",
      "ImageConfiguration": {
        "Port": "5090"
      }
    }
  }'
```

</details>

### Google Cloud

<details>
<summary>Click to expand Google Cloud deployment options</summary>

#### Google Cloud Run
```bash
gcloud run deploy webstar-server \
  --image ghcr.io/santasliar/webstar-server:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 5090
```

#### Google Compute Engine
Same as traditional servers - just install Docker and run the container.

</details>

### Microsoft Azure

<details>
<summary>Click to expand Azure deployment options</summary>

#### Azure Container Instances
```bash
az container create \
  --resource-group myResourceGroup \
  --name webstar-server \
  --image ghcr.io/santasliar/webstar-server:latest \
  --ports 5090 \
  --dns-name-label webstar-unique \
  --environment-variables ASPNETCORE_ENVIRONMENT=Production
```

#### Azure App Service
```bash
az webapp create \
  --resource-group myResourceGroup \
  --plan myAppServicePlan \
  --name webstar-app \
  --deployment-container-image-name ghcr.io/santasliar/webstar-server:latest
```

</details>

### Platform-as-a-Service

<details>
<summary>Click to expand PaaS deployment options</summary>

#### Heroku
1. Create `heroku.yml` in repository root:
```yaml
build:
  docker:
    web: webstar-server-dotnet/Dockerfile
run:
  web: dotnet WebStarServer.dll
```

2. Deploy:
```bash
heroku create your-app-name
heroku stack:set container
git push heroku main
```

#### Railway
1. Connect GitHub repository to Railway
2. Railway auto-detects Dockerfile
3. Set environment variable: `PORT=5090`
4. Deploy automatically on git push

#### Fly.io
```bash
flyctl launch --dockerfile webstar-server-dotnet/Dockerfile
flyctl deploy
```

#### Render
1. Connect GitHub repository
2. Select "Docker" as environment
3. Set Dockerfile path: `webstar-server-dotnet/Dockerfile`
4. Deploy

</details>

### Kubernetes

<details>
<summary>Click to expand Kubernetes deployment</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webstar-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webstar-server
  template:
    metadata:
      labels:
        app: webstar-server
    spec:
      containers:
      - name: webstar-server
        image: ghcr.io/santasliar/webstar-server:latest
        ports:
        - containerPort: 5090
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        livenessProbe:
          httpGet:
            path: /health
            port: 5090
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: webstar-service
spec:
  selector:
    app: webstar-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5090
  type: LoadBalancer
```

Deploy:
```bash
kubectl apply -f webstar-deployment.yaml
```

</details>

---

## Local Development

### Docker Compose
```yaml
version: '3.8'
services:
  webstar-server:
    build:
      context: ./webstar-server-dotnet
      dockerfile: Dockerfile
    ports:
      - "5090:5090"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
    restart: unless-stopped
```

Run locally:
```bash
docker-compose up -d
```

---

## Monitoring & Troubleshooting

### Health Checks
```bash
# Check if running
curl http://your-server/health

# Expected response:
{
  "status": "healthy",
  "uptime": 1234,
  "lobbies": 5,
  "clients": 12
}
```

### Container Management
```bash
# View logs
docker logs webstar-server --tail 50 -f

# Restart service
docker restart webstar-server

# Check resource usage
docker stats webstar-server

# Update to latest version
docker pull ghcr.io/santasliar/webstar-server:latest
docker stop webstar-server
docker rm webstar-server
# Then run the docker run command again
```

### Common Issues

<details>
<summary>Connection timeouts</summary>

- Check firewall settings
- Verify server URL is correct
- Ensure port 5090 is accessible
</details>

<details>
<summary>WebRTC failures</summary>

- Verify STUN servers are accessible
- Check NAT/firewall configuration
- Consider adding TURN servers for restrictive networks
</details>

<details>
<summary>High memory usage</summary>

- Monitor with `docker stats`
- Check for memory leaks in logs
- Consider scaling horizontally
</details>

---

## Environment Variables

Set these in your deployment platform:

- `ASPNETCORE_ENVIRONMENT=Production`
- `ASPNETCORE_URLS=http://+:5090`

## Security Considerations

- Use HTTPS in production
- Configure proper firewall rules
- Keep Docker and system updated
- Implement rate limiting if needed
- Use secrets management for sensitive data

---

## Scaling & Performance

### For High Traffic:
- Use load balancers (DigitalOcean, AWS ALB, etc.)
- Run multiple container instances
- Consider Redis for session storage
- Implement connection pooling

### Cost Optimization:
- **Free tiers**: Heroku, Railway, Render, Fly.io
- **Budget options**: DigitalOcean ($5/month), Hetzner, Vultr
- **Enterprise**: AWS, Google Cloud, Azure with auto-scaling

---

**🎉 Your WebStar server is now deployed and ready for multiplayer gaming!**

For support, check the [main README](README.md) or open an issue on GitHub.