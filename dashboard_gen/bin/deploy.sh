#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting deployment..."

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t dashboard-gen:latest .

# Run database migrations
echo "🗄️ Running database migrations..."
docker-compose run --rm app /app/bin/dashboard_gen eval "DashboardGen.Release.migrate()"

# Start the application
echo "▶️ Starting application..."
docker-compose up -d

echo "✅ Deployment complete!"
echo "🌐 Application should be available at http://localhost:4000"