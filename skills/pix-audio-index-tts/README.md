# pix-audio-index-tts

语音合成技能，将文本转换为自然流畅的语音。

## 功能

- 文本格式化：将书面文本转换为口语化脚本
- 文本分片：将长文本拆分为适合 TTS 的短片段
- 语音生成：使用参考音频生成语音
- 音频合并：将多个片段合并为完整音频

## 使用方法

### 激活方式

在 opencode 中使用以下方式激活：

- "将这段文字生成语音"
- "文字转语音"
- "配音"
- "TTS"

### 工作流程

```
- [ ] 1. 文本格式化 - 格式化输入文本
- [ ] 2. 文本分片 - 拆分成长度 ≤100 字符的片段
- [ ] 3. 语音生成 - 循环调用 tts_generate 生成每个片段
- [ ] 4. 音频合并 - 合并所有片段
- [ ] 5. 返回结果 - 返回下载链接或文件路径
```

## 快速开始

1. 启动 TTS 服务：
   ```bash
   uv run uvicorn src.index_tts_api.main:app --port 8002
   ```

2. 配置 MCP（如果未配置）：
   ```json
   {
     "mcp": {
       "index-tts": {
         "type": "local",
         "command": ["uv", "run", "python", "-m", "index_tts_mcp.server"],
         "environment": {
           "PYTHONPATH": "/path/to/index-tts-api",
           "TTS_BASE_URL": "http://localhost:8002"
         }
       }
     }
   }
   ```

3. 使用 skill：
   ```
   用户: "将今天天气真好这段文字生成语音"
   ```

## API 参考

### MCP 工具

| 工具 | 说明 |
|------|------|
| `text_split` | 文本分片 |
| `reference_list` | 列出参考音频 |
| `tts_generate` | 语音生成 |
| `audio_merge` | 音频合并 |

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| text | string | - | 要转换的文本 |
| reference_name | string | "liuyandong3" | 参考音频名称 |
| output_dir | string | "output" | 输出目录 |
| language | string | "Auto" | 语言代码 |
| emo_alpha | float | 参考音频默认值 | 情感强度 (0-1) |
| temperature | float | 参考音频默认值 | 采样温度 (0-1) |
| emo_text | string | 参考音频默认值 | 情感描述文本 |
| use_emo_text | bool | false | 是否使用文本情感模式 |
| **max_length** | int | **100** | ⚠️ **分片最大字符数，默认 100** |

## 目录结构

```
pix-audio-index-tts/
├── SKILL.md           # 技能定义
├── README.md           # 本文档
└── scripts/
    ├── __init__.py
    └── workflow.py    # 工作流封装
```
