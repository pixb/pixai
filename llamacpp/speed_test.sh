#!/bin/bash
# 测试 llama.cpp 模型推理速度

PORT=8080
BASE_URL="http://localhost:${PORT}"

echo "=== 模型速度测试 ==="
echo ""

# 获取模型信息
MODEL_INFO=$(curl -s --noproxy '*' "${BASE_URL}/v1/models" 2>/dev/null)
MODEL_NAME=$(echo "$MODEL_INFO" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//')
PARAM_SIZE=$(echo "$MODEL_INFO" | grep -o '"parameter_size":"[^"]*"' | head -1 | sed 's/"parameter_size":"//')

echo "模型: $MODEL_NAME"
echo "参数: $PARAM_SIZE"
echo ""

PROMPT="用python帮我写一个贪吃蛇小游戏"
echo "问题: $PROMPT"
echo ""
echo "开始计时..."
echo ""

RESPONSE=$(curl -s --noproxy '*' "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"messages\": [
      {\"role\": \"system\", \"content\": \"你是一个专业的Python程序员，只输出代码，不要解释\"},
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ],
    \"max_tokens\": 2048,
    \"temperature\": 0.7
  }")

# 解析响应
COMPLETION_TOKENS=$(echo "$RESPONSE" | grep -o '"completion_tokens":[0-9]*' | grep -o '[0-9]*')
PROMPT_TOKENS=$(echo "$RESPONSE" | grep -o '"prompt_tokens":[0-9]*' | grep -o '[0-9]*')
TOTAL_TOKENS=$(echo "$RESPONSE" | grep -o '"total_tokens":[0-9]*' | grep -o '[0-9]*')

# 从timings中提取时间
PREDICTED_MS=$(echo "$RESPONSE" | grep -o '"predicted_ms":[0-9.]*' | grep -o '[0-9.]*')
PROMPT_MS=$(echo "$RESPONSE" | grep -o '"prompt_ms":[0-9.]*' | grep -o '[0-9.]*')

# 计算速度
if [ -n "$COMPLETION_TOKENS" ] && [ -n "$PREDICTED_MS" ] && [ "$PREDICTED_MS" != "0" ]; then
    TOK_PER_SEC=$(echo "scale=2; $COMPLETION_TOKENS * 1000 / $PREDICTED_MS" | bc)
else
    TOK_PER_SEC="N/A"
fi

if [ -n "$PROMPT_TOKENS" ] && [ -n "$PROMPT_MS" ] && [ "$PROMPT_MS" != "0" ]; then
    PROMPT_TOK_PER_SEC=$(echo "scale=2; $PROMPT_TOKENS * 1000 / $PROMPT_MS" | bc)
else
    PROMPT_TOK_PER_SEC="N/A"
fi

# 输出结果
echo "========== 测试结果 =========="
echo ""
echo "Prompt tokens:   $PROMPT_TOKENS"
echo "Completion tokens: $COMPLETION_TOKENS"
echo "Total tokens:    $TOTAL_TOKENS"
echo ""
echo "Prompt 速度:     ${PROMPT_TOK_PER_SEC} tok/s"
echo "生成 速度:        ${TOK_PER_SEC} tok/s"
echo ""

# 输出代码片段
CONTENT=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | sed 's/\\n/\n/g;s/\\t/\t/g' | cut -c1-2000)
if [ -n "$CONTENT" ]; then
    echo "========== 代码预览 =========="
    echo "$CONTENT" | head -30
    if [ $(echo "$CONTENT" | wc -l) -gt 30 ]; then
        echo "..."
        echo "(共 $(echo "$CONTENT" | wc -l) 行)"
    fi
fi

echo ""
echo "================================="