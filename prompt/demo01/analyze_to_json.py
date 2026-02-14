import ollama
import json
from functools import lru_cache

@lru_cache(maxsize=128)
def analyze_to_json(raw_string):
    """
    使用本地部署的Qwen3-4B将字符串转换为JSON格式
    
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
    
    # 调用本地部署的 gemma3:4b（4B参数模型）
    response = ollama.generate(
        # model='gemma3:4b',
        model='qwen3:4b',
        prompt=prompt,
        options={
            'temperature': 0,  # 设为0以保证输出的稳定性
            'enable_thinking': False,
        }
    )
    
    # 提取并解析结果
    result_text = response['response'].strip()
    try:
        # 即使模型输出了 ```json ```，这里也可以简单清理
        clean_json = result_text.replace('```json', '').replace('```', '').strip()
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