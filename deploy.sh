#!/bin/bash

# WebStar Server Quick Deploy Script
# This script helps you deploy to various cloud platforms

echo "🚀 WebStar Server Deployment Helper"
echo "====================================="
echo ""
echo "Select your deployment platform:"
echo "1) DigitalOcean Droplet"
echo "2) AWS EC2"
echo "3) Google Cloud Compute Engine" 
echo "4) Azure Virtual Machine"
echo "5) Any Linux server with Docker"
echo "6) Heroku (Platform-as-a-Service)"
echo "7) Railway"
echo "8) Fly.io"
echo "9) Google Cloud Run"
echo "10) AWS Fargate"
echo ""

read -p "Enter your choice (1-10): " choice

# Common Docker image
IMAGE="ghcr.io/santasliar/webstar-server:latest"

case $choice in
    1|2|3|4|5)
        echo ""
        echo "📦 Docker deployment command for your server:"
        echo "=============================================="
        echo ""
        echo "# Pull and run the container"
        echo "docker pull $IMAGE"
        echo "docker run -d \\"
        echo "  --name webstar-server \\"
        echo "  --restart unless-stopped \\"
        echo "  -p 80:8080 \\"
        echo "  --health-cmd=\"curl -f http://localhost:8080/health || exit 1\" \\"
        echo "  --health-interval=30s \\"
        echo "  --health-timeout=10s \\"
        echo "  --health-retries=3 \\"
        echo "  $IMAGE"
        echo ""
        echo "# Check if it's running"
        echo "docker ps | grep webstar-server"
        echo "curl http://YOUR_SERVER_IP/health"
        ;;
    6)
        echo ""
        echo "🌐 Heroku deployment:"
        echo "===================="
        echo ""
        echo "1. Create heroku.yml in your repository root:"
        echo "build:"
        echo "  docker:"
        echo "    web: webstar-server-dotnet/Dockerfile"
        echo "run:"
        echo "  web: dotnet WebStarServer.dll"
        echo ""
        echo "2. Deploy:"
        echo "heroku create your-app-name"
        echo "heroku stack:set container"
        echo "git push heroku main"
        ;;
    7)
        echo ""
        echo "🚂 Railway deployment:"
        echo "====================="
        echo ""
        echo "1. Connect your GitHub repo to Railway"
        echo "2. Railway will auto-detect the Dockerfile"
        echo "3. Set environment variable: PORT=8080"
        echo "4. Deploy automatically on git push"
        ;;
    8)
        echo ""
        echo "🪰 Fly.io deployment:"
        echo "===================="
        echo ""
        echo "flyctl launch --dockerfile webstar-server-dotnet/Dockerfile"
        echo "flyctl deploy"
        ;;
    9)
        echo ""
        echo "☁️ Google Cloud Run deployment:"
        echo "=============================="
        echo ""
        echo "gcloud run deploy webstar-server \\"
        echo "  --image $IMAGE \\"
        echo "  --platform managed \\"
        echo "  --region us-central1 \\"
        echo "  --allow-unauthenticated \\"
        echo "  --port 8080"
        ;;
    10)
        echo ""
        echo "🛡️ AWS Fargate deployment:"
        echo "=========================="
        echo ""
        echo "1. Create ECS cluster and task definition"
        echo "2. Use image: $IMAGE"
        echo "3. Configure port mapping: 8080"
        echo "4. Set health check: /health endpoint"
        echo ""
        echo "See DEPLOYMENT-MULTIPLATFORM.md for detailed instructions"
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📚 For detailed instructions, see:"
echo "- DEPLOYMENT.md (general Docker deployment)"
echo "- DEPLOYMENT-MULTIPLATFORM.md (platform-specific guides)"
echo ""
echo "🔧 Need help? Check the health endpoint after deployment:"
echo "curl http://your-domain/health"
