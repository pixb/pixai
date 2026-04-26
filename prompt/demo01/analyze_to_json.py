import requests
import json
from functools import lru_cache

OLLAMA_HOST = "http://192.168.1.7:11434"


@lru_cache(maxsize=128)
def analyze_to_json(raw_string):
    """
    使用远程部署的Qwen3-4B将字符串转换为JSON格式

    Args:
        raw_string: 待分析的原始字符串

    Returns:
        dict: 解析后的JSON对象，解析失败返回None
    """
    # 定义任务描述
    prompt = f"""
    分析以下字符串并转化为JSON。
    要求格式：{{"user": "姓名", "action": "动作", "amount": "数值"}}
    注意：只返回JSON，不要解释。
    
    待处理字符串："{raw_string}"
    """

    # 调用远程 192.168.1.7 的 ollama 服务
    response = requests.post(
        f"{OLLAMA_HOST}/api/chat",
        json={
            "model": "qwen3-vl:4b",
            "messages": [{"role": "user", "content": prompt}],
            "options": {
                "temperature": 0,
            },
            "stream": False,
        },
        timeout=120,
    )
    response.raise_for_status()

    # 提取并解析结果
    result_text = response.json()["message"]["content"].strip()
    try:
        # 即使模型输出了 ```json ```，这里也可以简单清理
        clean_json = result_text.replace("```json", "").replace("```", "").strip()
        return json.loads(clean_json)
    except Exception as e:
        print(f"解析失败: {e}")
        return None


# 测试
if __name__ == "__main__":
    import time

    test_string = "张三在昨天下午两点充值了500元"

    # 第一次调用（无缓存）
    start = time.time()
    data = analyze_to_json(test_string)
    first_call_time = time.time() - start
    print(f"第一次调用结果: {data}")
    print(f"第一次调用耗时: {first_call_time:.2f}秒")

    # 第二次调用（有缓存）
    test_string = "李四在昨天下午两点充值了600元"
    start = time.time()
    data = analyze_to_json(test_string)
    cached_call_time = time.time() - start
    print(f"\n第二次调用结果: {data}")
    print(f"第二次调用耗时: {cached_call_time:.4f}秒（使用缓存）")

    if cached_call_time > 0:
        print(f"\n性能提升: {first_call_time / cached_call_time:.0f}倍")
    else:
        print(f"\n性能提升: 几乎无限倍（缓存命中）")
