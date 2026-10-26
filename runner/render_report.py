"""Render a portable Markdown baseline report from collected JSON artifacts."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def render(results: Path) -> str:
    preflight = load(results / "preflight.json") or {}
    gpu_names = ", ".join(gpu.get("name", "unknown") for gpu in preflight.get("gpus", [])) or "未偵測"
    lines = [
        "# NVIDIA Full-Stack Baseline Report",
        "",
        f"- 產生時間：{datetime.now(timezone.utc).isoformat()}",
        f"- GPU：{gpu_names}",
        f"- Driver：{preflight.get('driver') or 'unknown'}",
        f"- InfiniBand：{'yes' if preflight.get('infiniband') else 'no'}",
        "",
        "## 結果",
        "",
        "| Lab | 狀態 | 摘要 |",
        "|---|---|---|",
    ]
    mapping = {
        "cuda.json": "CUDA residency",
        "diagnostics.json": "GPU diagnostics",
        "pod.json": "POD planner",
        "rdma-summary.json": "RDMA / NCCL",
        "rapids.json": "RAPIDS",
        "dask.json": "Dask multi-GPU",
    }
    for filename, label in mapping.items():
        data = load(results / filename)
        if data is None:
            lines.append(f"| {label} | skipped/failed | 無有效 JSON |")
        else:
            summary = json.dumps(data, ensure_ascii=False, separators=(",", ":"))[:240]
            lines.append(f"| {label} | completed | `{summary}` |")
    lines.extend(["", "## 原始資料", "", "所有 JSON、拓撲與命令輸出均與本報告一同保存於 GitHub Actions artifact。", ""])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(render(args.results), encoding="utf-8")


if __name__ == "__main__":
    main()
