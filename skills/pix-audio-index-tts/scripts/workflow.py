"""
TTS Workflow for pix-audio-index-tts skill.
"""
import re
from typing import Optional


def format_tts_text(text: str) -> str:
    """格式化文本为适合 TTS 朗读的口语化脚本
    
    Rules:
    1. 数字与单位连接: 2022年, 100%, 50kg
    2. 日期时间标准化: 2023-10-01 -> 2023年10月1日, 12:30 -> 12点30分
    3. 特殊符号处理: & -> 和, @ -> 在
    4. 去除干扰符号: Markdown, URL, 注脚
    5. 多音字与断句优化
    """
    if not text:
        return text
    
    formatted = text
    
    formatted = re.sub(r'(\d+)\s*([年日月时分秒])', r'\1\2', formatted)
    formatted = re.sub(r'(\d+)\s*%', r'\1%', formatted)
    formatted = re.sub(r'(\d+)\s*(kg|克|g|米|m|cm|毫米)', r'\1\2', formatted)
    
    formatted = re.sub(r'(\d{4})-(\d{1,2})-(\d{1,2})', r'\1年\2月\3日', formatted)
    formatted = re.sub(r'(\d{1,2}):(\d{2})', r'\1点\2分', formatted)
    
    formatted = formatted.replace('&', '和')
    formatted = formatted.replace('@', '在')
    formatted = re.sub(r'[#*~]', '', formatted)
    
    formatted = re.sub(r'\*\*([^*]+)\*\*', r'\1', formatted)
    formatted = re.sub(r'##\s*', '', formatted)
    formatted = re.sub(r'#\s*', '', formatted)
    formatted = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', formatted)
    formatted = re.sub(r'`([^`]+)`', r'\1', formatted)
    
    formatted = re.sub(r'https?://[^\s]+', '', formatted)
    
    formatted = re.sub(r'\[\d+\]', '', formatted)
    formatted = re.sub(r'\(注[：:]?[^)]*\)', '', formatted)
    
    formatted = re.sub(r'\s+', ' ', formatted)
    
    return formatted.strip()


async def text_to_speech(
    text: str,
    reference_name: str = "liuyandong3",
    output_dir: str = "output",
    language: str = "Auto",
    emo_alpha: Optional[float] = None,
    temperature: Optional[float] = None,
    emo_text: Optional[str] = None,
    use_emo_text: bool = False,
    max_length: int = 100,
) -> dict:
    """将文本转换为语音的完整工作流
    
    Args:
        text: 要转换的文本
        reference_name: 参考音频名称
        output_dir: 输出目录
        language: 语言代码
        emo_alpha: 情感强度 (0-1)
        temperature: 采样温度 (0-1)
        emo_text: 情感描述文本
        use_emo_text: 是否使用文本情感模式
        max_length: 分片最大长度
    
    Returns:
        包含 success、file_path、download_url 的字典
    """
    from index_tts_mcp.server import text_split, tts_generate, audio_merge
    
    formatted_text = format_tts_text(text)
    
    split_result = await text_split(type('Params', (), {
        'text': formatted_text,
        'max_length': max_length,
        'min_chunk_length': 50
    })())
    
    import json
    split_data = json.loads(split_result)
    
    if not split_data.get("success"):
        return {"success": False, "error": f"文本分片失败: {split_data.get('error')}"}
    
    chunks = split_data.get("chunks", [])
    
    if not chunks:
        return {"success": False, "error": "没有需要处理的文本片段"}
    
    audio_files = []
    for chunk in chunks:
        result = await tts_generate(type('Params', (), {
            'text': chunk,
            'reference_name': reference_name,
            'ref_text': "",
            'language': language,
            'emo_alpha': emo_alpha,
            'temperature': temperature,
            'emo_text': emo_text,
            'use_emo_text': use_emo_text,
            'output_dir': output_dir,
            'reference_id': None
        })())
        
        result_data = json.loads(result)
        
        if not result_data.get("success"):
            return {"success": False, "error": f"语音生成失败: {result_data.get('error')}"}
        
        audio_files.append(result_data["file_path"])
    
    if len(audio_files) == 1:
        return json.loads(result)
    
    merge_result = await audio_merge(type('Params', (), {
        'files': audio_files,
        'output_dir': output_dir
    })())
    
    merge_data = json.loads(merge_result)
    return merge_data
