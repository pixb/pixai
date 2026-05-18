# vllm

## env

根據 vLLM 官方文件與社群回饋：
推薦版本：Python 3.10 或 3.12。
支援範圍：通常為 3.9 – 3.12。
Python 3.8：舊版本 vLLM 支援，但由於 PyTorch 2.5 已停止支援 3.8，新版 vLLM 已不再支援。
Python 3.13：最新版本（如 v0.10.1+）已開始逐步支援，但在某些環境（如 Arch Linux AUR）中可能仍存在相容性問題

```bash
pyenv install 3.12.13
```

```bash
pyenv global 3.12.13
```

```bash
pip install -r requirements.txt
```

验证:

```bash
 python -c "import vllm; print('vLLM installed')"
vLLM installed
```
