#!/bin/bash
# Test script for llama.cpp API Server

PORT=8080
BASE_URL="http://localhost:${PORT}"

echo "Testing llama.cpp API Server..."
echo ""

# Check if server is running
echo "1. Health check..."
curl -s "${BASE_URL}/health" | jq . 2>/dev/null || echo "Server may not be running or jq not installed"
echo ""

# Get available models
echo "2. Available models..."
curl -s "${BASE_URL}/v1/models" | jq . 2>/dev/null || curl -s "${BASE_URL}/v1/models"
echo ""

# Simple chat completion test
echo "3. Chat completion test..."
curl -s "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "stream": false
  }' | jq . 2>/dev/null || curl -s "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "stream": false
  }'
echo ""

# Streaming test
echo "4. Streaming test..."
curl -s "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Count to 3"}
    ],
    "stream": true
  }'
echo ""
echo "(Streaming completed)"
