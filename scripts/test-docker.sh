#!/bin/bash
# Test Docker build and functionality

set -e

echo "🐳 Testing Docker build and functionality..."

# Build the image
echo "📦 Building Docker image..."
docker build -t shot-stitch:test .

# Test help command
echo "🧪 Testing help command..."
docker run --rm shot-stitch:test --help

# Test with a sample video (if available)
if [ -f "tests/fixtures/test_video_30s.mp4" ]; then
    echo "🎬 Testing with sample video..."
    docker run --rm \
        -v "$(pwd)/tests/fixtures:/data" \
        shot-stitch:test \
        /data/test_video_30s.mp4 \
        --preset quick \
        --force
    
    echo "✅ Docker test completed successfully!"
else
    echo "⚠️  No test video found, skipping video test"
    echo "✅ Docker build test completed successfully!"
fi

# Clean up test image
echo "🧹 Cleaning up test image..."
docker rmi shot-stitch:test

echo "🎉 All tests passed!"
