#!/bin/bash
# Simple test script for official Supabase setup

echo "🚀 Testing AI Brain Supabase Official Setup"

# Check Docker
if ! docker info &> /dev/null; then
    echo "❌ Docker not running"
    exit 1
fi

# Check compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not available"
    exit 1
fi

echo "✅ Using $COMPOSE_CMD"

# Check files
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml missing"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "❌ .env missing"  
    exit 1
fi

echo "✅ Configuration files present"

# Check key volumes
if [ ! -f "volumes/api/kong.yml" ]; then
    echo "❌ Kong config missing"
    exit 1
fi

if [ ! -f "volumes/db/init/01-rag-schema.sql" ]; then
    echo "❌ RAG schema missing"
    exit 1
fi

echo "✅ Volume configurations present"

# Test compose file syntax
if ! $COMPOSE_CMD config &> /dev/null; then
    echo "❌ Docker Compose configuration invalid"
    exit 1
fi

echo "✅ Docker Compose configuration valid"

echo ""
echo "🎉 All checks passed! Ready to start services:"
echo ""
echo "  Start:  $COMPOSE_CMD up -d"
echo "  Status: $COMPOSE_CMD ps"  
echo "  Logs:   $COMPOSE_CMD logs -f"
echo "  Stop:   $COMPOSE_CMD down"
echo ""
echo "Access points after startup:"
echo "  Studio: http://localhost:3000"
echo "  API:    http://localhost:8000"