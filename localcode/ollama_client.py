import requests

OLLAMA_HOST = "http://192.168.1.7:11434"
MODEL = "qwen3-vl:4b"


def chat(messages: list[dict], model: str = MODEL) -> str:
    """调用本地 Ollama 模型"""
    response = requests.post(
        f"{OLLAMA_HOST}/api/chat",
        json={
            "model": model,
            "messages": messages,
            "options": {"temperature": 0},
            "stream": False,
        },
        timeout=120,
    )
    response.raise_for_status()
    return response.json()["message"]["content"]


def main():
    response = chat(
        messages=[{"role": "user", "content": "Hello"}],
    )
    print(response)


if __name__ == "__main__":
    main()
