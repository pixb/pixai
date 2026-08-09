import ollama
import json
from functools import lru_cache

# 装备名称修正映射表
EQUIPMENT_NAME_FIXES = {
    "天鸽之声": "天鹅之声",
    # 可以添加其他常见识别错误
}


@lru_cache(maxsize=32)  # 缓存32张图片的分析结果
def analyze_image(image_path):
    """
    使用本地部署的Qwen3-VL分析图片内容
    
    Args:
        image_path: 图片文件路径
        
    Returns:
        dict: 包含图片分析结果的字典
    """
    # 定义分析任务，要求返回JSON格式
    prompt = """
    分析这张游戏装备图片，提取所有信息并以JSON格式返回。
    
    重要提示：
    - 特别注意识别装备名称，可能包含'天鹅之声'等名称
    - 确保装备名称识别准确，仔细查看图片中的每个字符
    - 常见装备名称格式：[名称][稀有度][类型]，如"急雷远古枪"
    
    具体要求：
    1. 从装备名称中拆分：
       - name: 装备名称（如"急雷"）
       - rarity: 稀有度（如"远古"）
       - type: 装备类型（如"枪"）
    
    2. 从等级信息中提取：
       - level: 等级数值（如"11"）
       - phase: phase值（如"P51"中的"51"）
    
    3. 提取装备数值：
       - base_value: 基础数值（如"2334"）
       - price: 价格（如"4078 G"中的"4078"）
    
    4. 提取特效：
       - stardust_effect: 星尘特效（每次成功对一个目标造成冰冻、眩晕或恐惧效果的相关描述）
       - effect: 特效（所有具有特殊效果的描述，如充能、提高属性、伤害加成等机制性效果）
    
    5. 提取所有属性加成：
       - attributes: 包含所有属性的对象，键为属性名，值为属性值
       - 例如：{"力量": "2334", "命中修正": "11.7%", ...}
    
    6. 其他信息：
       - gem_slots: 宝石孔数量
       - description: 装备描述（装备的背景故事、来源、基本介绍等非机制性描述）
    
    重要区分：
    - description: 通常是对装备的基本介绍，不包含具体的游戏机制效果
    - effect: 通常包含具体的游戏机制效果，如充能、属性提升、伤害加成等
    
    注意：
    - 只返回JSON，不要有任何解释
    - 确保JSON格式正确
    - 所有字段都要从图片中提取，不要猜测
    - 如果某些字段不存在，设为null
    """
    
    # 调用本地部署的 qwen3-vl:4b-instruct
    response = ollama.generate(
        model='qwen3-vl:4b-instruct',
        prompt=prompt,
        images=[image_path],  # 传递图片路径
        options={
            'temperature': 0,  # 设为0以保证输出的稳定性
        }
    )
    
    # 提取并解析结果
    result_text = response['response'].strip()
    try:
        # 清理JSON格式
        clean_json = result_text.replace('```json', '').replace('```', '').strip()
        result = json.loads(clean_json)
        
        # 应用装备名称修正
        if 'name' in result and result['name'] in EQUIPMENT_NAME_FIXES:
            result['name'] = EQUIPMENT_NAME_FIXES[result['name']]
        
        return {
            "image_path": image_path,
            "analysis": result
        }
    except Exception as e:
        print(f"解析失败: {e}")
        return {
            "image_path": image_path,
            "analysis": {
                "error": f"解析失败: {e}",
                "raw_response": result_text
            }
        }

# 测试
if __name__ == "__main__":
    import time
    
    # 测试第一件装备图片
    test_image1 = "c:\\Users\\pix\\dev\\code\\ai\\pixai\\res\\1.png"  # 急雷枪
    print("分析第一件装备中...")
    start = time.time()
    image_result1 = analyze_image(test_image1)
    end = time.time()
    print(f"图片分析耗时: {end - start:.2f}秒")
    print(f"图片路径: {image_result1['image_path']}")
    print(f"分析结果: {image_result1['analysis']}")
    
    print("\n" + "-" * 50 + "\n")
    
    # 测试第二件装备图片
    test_image2 = "c:\\Users\\pix\\dev\\code\\ai\\pixai\\res\\2.png"  # 天鹅之声
    print("分析第二件装备中...")
    start = time.time()
    image_result2 = analyze_image(test_image2)
    end = time.time()
    print(f"图片分析耗时: {end - start:.2f}秒")
    print(f"图片路径: {image_result2['image_path']}")
    print(f"分析结果: {image_result2['analysis']}")
    
    print("\n" + "-" * 50 + "\n")
    
    # 测试第三件装备图片
    test_image3 = "c:\\Users\\pix\\dev\\code\\ai\\pixai\\res\\3.png"  # 明剑
    print("分析第三件装备中...")
    start = time.time()
    image_result3 = analyze_image(test_image3)
    end = time.time()
    print(f"图片分析耗时: {end - start:.2f}秒")
    print(f"图片路径: {image_result3['image_path']}")
    print(f"分析结果: {image_result3['analysis']}")
