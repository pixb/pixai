from openai import OpenAI
import json
from functools import lru_cache
from typing import Optional

llama_client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="not-needed"
)

MODEL_NAME = "qwen2.5-1.5b"

_messages_cache: dict[str, str] = {}

def chat_with_llama(
    system: str,
    user: str, 
    temperature: float = 0.7, 
    max_tokens: int = 512
) -> str:
    """
    使用 llama.cpp API 进行对话
    
    Args:
        system: 系统提示
        user: 用户输入
        temperature: 温度参数
        max_tokens: 最大生成长度
        
    Returns:
        str: 模型回复内容
    """
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user}
    ]
    cache_key = f"{system}:{user}:{temperature}:{max_tokens}"
    
    if cache_key in _messages_cache:
        return _messages_cache[cache_key]
    
    response = llama_client.chat.completions.create(
        model=MODEL_NAME,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tokens
    )
    result = response.choices[0].message.content
    _messages_cache[cache_key] = result
    return result


def analyze_to_json(raw_string: str) -> Optional[dict]:
    """
    使用 llama.cpp 将字符串转换为 JSON 格式
    
    Args:
        raw_string: 待分析的原始字符串
        
    Returns:
        dict: 解析后的JSON对象
    """
    prompt = f"""分析以下字符串并转化为JSON。
要求格式：{{"user": "姓名", "action": "动作", "amount": "数值"}}
注意：只返回JSON，不要解释。

待处理字符串："{raw_string}"
"""
    
    result_text = chat_with_llama(
        system="你是一个JSON转换助手，只返回JSON格式的结果。",
        user=prompt,
        temperature=0,
        max_tokens=256
    )
    
    try:
        clean_json = result_text.replace('```json', '').replace('```', '').strip()
        return json.loads(clean_json)
    except Exception as e:
        print(f"解析失败: {e}")
        return None


def get_embedding(text):
    """
    获取文本的embedding向量
    
    Args:
        text: 输入文本
        
    Returns:
        list: embedding向量
    """
    response = llama_client.embeddings.create(
        model=MODEL_NAME,
        input=text
    )
    return response.data[0].embedding


if __name__ == "__main__":
    import time
    
    print("=== 对话测试 ===")
    start = time.time()
    response = chat_with_llama(
        system="你是一个有帮助的助手。",
        user="请介绍一下量子计算的基本原理。",
        temperature=0.7,
        max_tokens=200
    )
    print(f"回复: {response}")
    print(f"耗时: {time.time() - start:.2f}秒")
    
    print("\n=== JSON转换测试 ===")
    test_string = "张三在昨天下午两点充值了500元"
    data = analyze_to_json(test_string)
    print(f"结果: {data}")
    
    print("\n=== Embedding测试 ===")
    text = "Hello, world!"
    embedding = get_embedding(text)
    print(f"Embedding维度: {len(embedding)}")
    print(f"前5个值: {embedding[:5]}")
