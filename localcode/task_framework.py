from pathlib import Path


TASKS_FILE = Path(__file__).parent / "tasks.md"


def load_tasks() -> list[dict]:
    """加载任务列表"""
    if not TASKS_FILE.exists():
        return []
    content = TASKS_FILE.read_text()
    tasks = []
    for line in content.splitlines():
        if line.startswith("- [ ]") or line.startswith("- [x]"):
            done = line.startswith("- [x]")
            name = line.replace("- [ ]", "").replace("- [x]", "").strip()
            tasks.append({"name": name, "done": done})
    return tasks


def save_tasks(tasks: list[dict]) -> None:
    """保存任务列表"""
    lines = ["# 任务拆分框架\n", "\n", "## 001-连接 Ollama API\n", "\n", "### 子任务\n"]
    for task in tasks:
        mark = "[x]" if task["done"] else "[ ]"
        lines.append(f"- {mark} {task['name']}\n")
    TASKS_FILE.write_text("".join(lines))


def get_pending_tasks() -> list[dict]:
    """获取待完成任务"""
    return [t for t in load_tasks() if not t["done"]]


def mark_done(name: str) -> None:
    """标记任务完成"""
    tasks = load_tasks()
    for task in tasks:
        if task["name"] == name:
            task["done"] = True
            break
    save_tasks(tasks)


if __name__ == "__main__":
    print("待完成任务:")
    for task in get_pending_tasks():
        print(f"  - {task['name']}")
