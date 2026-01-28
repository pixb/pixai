# Skills 目录项目总结

## 项目概览

本目录包含了各种技能(Skills)项目,用于支持不同的开发任务和工作流程。

## 项目分类

### Go 项目开发相关

| 项目名称 | 作用说明 |
|---------|----------|
| go-project-overview | Go 项目整体结构、技术栈和核心命令概览 |
| go-project-conventions | Go 代码规范,包括错误处理、导入、lint 和工作流程 |
| go-project-main | CLI 入口点模式,使用 Cobra/Viper 配置和优雅关闭 |
| go-project-server | Echo + Connect RPC 服务器实现,支持双协议和认证 |
| go-project-proto | Protocol Buffer 配置,使用 buf 生成代码 |
| go-project-store | 数据存储层,包括 Driver 接口、缓存和迁移系统 |
| go-project-scripts | 构建脚本、Dockerfile 和部署配置 |

### Obsidian 相关

| 项目名称 | 作用说明 |
|---------|----------|
| obsidian-markdown | Obsidian 风格 Markdown,支持 wikilinks、嵌入、callouts 等 |
| obsidian-bases | Obsidian Bases 创建和编辑,支持视图、过滤器和公式 |
| obsidian-canvas-creator | 从文本创建 Obsidian Canvas,支持思维导图和自由布局 |

### 可视化工具

| 项目名称 | 作用说明 |
|---------|----------|
| excalidraw-diagram | 生成 Excalidraw 图表,用于 Obsidian 中的可视化 |
| mermaid-visualizer | 将文本转换为 Mermaid 图表,支持流程图、架构图等 |
| json-canvas | 创建和编辑 JSON Canvas 文件,支持节点和边 |

### 其他工具

| 项目名称 | 作用说明 |
|---------|----------|
| pix-question-answer | 规范化的问题回答流程,适用于概念解释和技术术语说明 |
| pix-chat-save | 自动保存聊天对话到 Markdown 文件 |
| pix-cognitive-tutor | 基于五步教学法的认知导师技能,结构化解释技术概念 |
| pix-skill-creator | 元技能,用于创建完整的 Trae agent skill |

## 技术栈总览

### Go 生态
- **Web 框架**: Echo v4
- **RPC**: Connect RPC + gRPC-Gateway
- **协议**: Protocol Buffers (buf 工具链)
- **数据库**: Driver 接口模式支持 SQLite/MySQL/PostgreSQL
- **认证**: JWT、Refresh Token、PAT

### 可视化工具
- **Excalidraw**: 手绘风格图表
- **Mermaid**: 专业的流程图和架构图
- **JSON Canvas**: 无限画布格式

### 笔记工具
- **Obsidian**: 支持 Markdown 风格扩展
- **Bases**: 类似数据库的笔记视图
- **Canvas**: 可视化笔记组织

## 快速链接

- [Go 项目开发文档](./go-project-overview/)
- [Obsidian 技能指南](./obsidian-markdown/)
- [可视化工具合集](./mermaid-visualizer/)
