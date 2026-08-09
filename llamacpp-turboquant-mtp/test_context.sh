#!/bin/bash
# 上下文窗口测试脚本

HOST="${1:-localhost}"
PORT="${2:-8080}"
MODEL="${3:-Qwen3.6-27B-Q4_K_M.gguf}"

echo "=============================================="
echo "       TurboQuant Context Window Test"
echo "=============================================="
echo "Server: http://${HOST}:${PORT}"
echo ""

test_ctx() {
    local tokens=$1
    local fill_word="${2:-x}"
    local name="${3:-Test}"

    echo -n "Testing ${name} (${tokens} tokens)... "

    # Generate content
    content=$(python3 -c "print(' ${fill_word}'.join(['']*${tokens}))" 2>/dev/null)
    prompt="${content} CODE123 is secret. What is CODE123?"

    # Save to temp file
    echo "{\"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}], \"max_tokens\": 15}" > /tmp/ctx_test.json

    start=$(date +%s.%N)

    response=$(curl --noproxy '*' -s -w "\nHTTP:%{http_code}" \
        "http://${HOST}:${PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '@/tmp/ctx_test.json' 2>/dev/null)

    http_code=$(echo "$response" | grep "HTTP:" | cut -d: -f2)
    body=$(echo "$response" | grep -v "HTTP:")

    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc)

    if [ "$http_code" = "200" ]; then
        content=$(echo "$body" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4)
        tokens=$(echo "$body" | grep -o '"total_tokens":[0-9]*' | cut -d: -f2)
        echo "✅ OK | Tokens: ${tokens} | Time: ${duration}s"
    elif [ "$http_code" = "400" ]; then
        echo "❌ Too many tokens"
    else
        echo "⚠️ HTTP $http_code"
    fi
}

echo "--- Context Tests ---"
test_ctx 1000 "word" "Short"
test_ctx 10000 "word" "Medium"
test_ctx 50000 "the" "Large"
test_ctx 100000 "a" "Very Large"
test_ctx 120000 "x" "Near 128K"

echo ""
echo "--- Memory Check ---"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "Test completed!"