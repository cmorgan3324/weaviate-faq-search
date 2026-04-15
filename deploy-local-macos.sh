#!/bin/bash
set -euo pipefail

echo "=== Local macOS Development Deployment ==="
echo "This sets up the complete stack (Weaviate + Streamlit) locally"
echo

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is for macOS only. Use deploy-zero-touch.sh on EC2."
    exit 1
fi

# 1) Check dependencies
echo "1) Checking dependencies..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop for Mac"
    echo "   Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Desktop (includes Compose)"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop"
    exit 1
fi

echo "✓ Docker and Docker Compose are available"

# 2) Stop any existing containers
echo "2) Cleaning up existing containers..."
docker-compose down 2>/dev/null || true
docker stop weaviate-faq 2>/dev/null || true
docker rm weaviate-faq 2>/dev/null || true

# 3) Start the complete stack
echo "3) Starting Weaviate + Streamlit stack..."
docker-compose up -d

echo "✓ Stack started successfully"

# 4) Wait for Weaviate to be ready and set it up
echo "4) Setting up Weaviate with sample data..."
sleep 10  # Give Weaviate time to start

# Install weaviate-client if not available
if ! python3 -c "import weaviate" 2>/dev/null; then
    echo "Installing weaviate-client..."
    pip3 install weaviate-client
fi

# Run setup script
python3 setup_weaviate.py

# 5) Test the application
echo "5) Testing application..."
sleep 5

if curl -s http://localhost:8501 > /dev/null; then
    echo "✓ Streamlit app is responding"
else
    echo "❌ Streamlit not responding, checking logs..."
    docker-compose logs streamlit-app
    exit 1
fi

if curl -s http://localhost:8080/v1/.well-known/ready > /dev/null; then
    echo "✓ Weaviate is responding"
else
    echo "❌ Weaviate not responding, checking logs..."
    docker-compose logs weaviate
    exit 1
fi

# 6) Show status
echo
echo "=== LOCAL DEPLOYMENT COMPLETE ==="
echo "🚀 Your app is running at: http://localhost:8501/faq-search-demo"
echo "🔍 Weaviate API is available at: http://localhost:8080"
echo
echo "Useful commands:"
echo "  View logs:        docker-compose logs -f"
echo "  Stop stack:       docker-compose down"
echo "  Restart stack:    docker-compose restart"
echo "  View Weaviate:    curl http://localhost:8080/v1/.well-known/ready"
echo
echo "When ready for EC2 deployment:"
echo "  1. Copy project to EC2: scp -r . ec2-user@your-instance:/home/ec2-user/weviate-faq-search"
echo "  2. SSH to EC2 and run: ./deploy-zero-touch.sh"