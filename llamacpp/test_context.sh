#!/bin/bash
# 长上下文测试脚本

HOST="${1:-localhost}"
PORT="${2:-8080}"
MODEL="${3:-Qwen3.6-27B-Q4_K_M.gguf}"

test_context() {
    local tokens=$1
    local content=$(printf 'word%.0s ' $(seq 1 $tokens) | head -c 50000)

    echo "Testing context length: ~$tokens tokens"
    echo "---"

    start_time=$(date +%s.%N)

    response=$(curl --noproxy '*' -s -w "\n%{http_code}" http://${HOST}:${PORT}/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${MODEL}\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Count the words in the following text and just say the number:\n${content}\"}],
            \"max_tokens\": 10,
            \"temperature\": 0.1
        }" 2>/dev/null)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)

    if [ "$http_code" = "200" ]; then
        content_length=$(echo "$body" | grep -o '"total_tokens":[0-9]*' | cut -d: -f2)
        echo "Status: OK | Tokens: $content_length | Time: ${duration}s"
    else
        echo "Status: FAILED (HTTP $http_code)"
        echo "$body" | head -c 200
    fi
    echo ""
}

echo "=============================================="
echo "       Long Context Test (TurboQuant)"
echo "=============================================="
echo "Server: http://${HOST}:${PORT}"
echo ""

test_context 1000
test_context 5000
test_context 10000
test_context 50000
test_context 100000
test_context 200000

echo "=============================================="
echo "Test completed"