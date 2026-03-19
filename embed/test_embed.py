from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="no-key")
response = client.embeddings.create(
    model="mxbai-embed-large",
    input="今天天气真好"
)
print(len(response.data[0].embedding))  # 输出: 1024
