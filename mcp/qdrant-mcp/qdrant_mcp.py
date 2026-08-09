import ollama
from mcp.server.fastapi import FastAPIServer
from qdrant_client import QdrantClient

# 1. 初始化 Qdrant 客户端（指向你刚才存好 11MB 小说的服务）
qdrant_client = QdrantClient(url="http://localhost:6333") 
# 2. 创建 MCP 服务
server = FastAPIServer(name="Qdrant Novel Knowledge Base")

@server.tool()
async def search_novel(query: str) -> str:
    """当你需要查询或理解这本中文小说的剧情、人名、背景、功法、境界、设定时，调用此工具。"""
    
    # 使用你指定的本地 Ollama 转换为 2560 维向量
    response = ollama.embeddings(model="qwen3-embedding:4b-q4_K_M", prompt=query)
    query_vector = response["embedding"]
    
    # 直接去检索你在 n8n 里自动创建好的 '0' 号库，精准捞回 8 条最相关的上下文
    search_result = qdrant_client.search(
        collection_name="0", 
        query_vector=query_vector, 
        limit=8
    )
    
    # 拼接提取出的中文小说文本块
    context_list = [hit.payload.get("txt", "") for hit in search_result]
    return "\n\n---\n\n".join(context_list)

if __name__ == "__main__":
    server.run(transport="stdio")
