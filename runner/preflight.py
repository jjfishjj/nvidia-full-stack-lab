"""Validate a Linux host before it is registered as an NVIDIA GitHub runner."""

from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def command(args: list[str], timeout: int = 30) -> dict:
    try:
        completed = subprocess.run(args, text=True, capture_output=True, timeout=timeout, check=False)
        return {"ok": completed.returncode == 0, "returncode": completed.returncode, "stdout": completed.stdout.strip(), "stderr": completed.stderr.strip()}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "returncode": None, "stdout": "", "stderr": str(exc)}


def parse_gpu_csv(text: str) -> list[dict]:
    gpus = []
    for line in text.splitlines():
        if not line.strip():
            continue
        columns = [value.strip() for value in line.split(",")]
        if len(columns) != 5:
            raise ValueError(f"unexpected nvidia-smi row: {line}")
        index, name, uuid, memory_mib, capability = columns
        gpus.append({"index": int(index), "name": name, "uuid": uuid, "memory_mib": int(memory_mib), "compute_capability": capability})
    return gpus


def inspect(container_check: bool = False) -> dict:
    query = command(["nvidia-smi", "--query-gpu=index,name,uuid,memory.total,compute_cap", "--format=csv,noheader,nounits"])
    driver = command(["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"])
    docker = command(["docker", "version", "--format", "{{.Server.Version}}"])
    result = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "host": {"system": platform.system(), "release": platform.release(), "machine": platform.machine(), "python": platform.python_version()},
        "commands": {name: shutil.which(name) for name in ["nvidia-smi", "docker", "ibstat", "ib_write_bw", "dcgmi", "nvcc"]},
        "driver": driver["stdout"].splitlines()[0] if driver["ok"] and driver["stdout"] else None,
        "gpus": parse_gpu_csv(query["stdout"]) if query["ok"] else [],
        "docker": {"ok": docker["ok"], "version": docker["stdout"], "error": docker["stderr"]},
        "infiniband": Path("/sys/class/infiniband").is_dir() and any(Path("/sys/class/infiniband").iterdir()),
        "dcgm_available": shutil.which("dcgmi") is not None,
    }
    if container_check and docker["ok"]:
        container = command(["docker", "run", "--rm", "--gpus", "all", "nvidia/cuda:13.4.3-base-ubuntu24.04", "nvidia-smi", "-L"], timeout=300)
        result["container_gpu"] = {"ok": container["ok"], "output": container["stdout"], "error": container["stderr"]}
    labels = ["self-hosted", "linux", platform.machine().lower()]
    if result["gpus"]:
        labels.append("gpu")
    if result["infiniband"]:
        labels.append("infiniband")
    result["eligible_labels"] = labels
    result["ready"] = bool(result["gpus"] and docker["ok"] and (not container_check or result.get("container_gpu", {}).get("ok")))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container-check", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = inspect(args.container_check)
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    print(payload)
    raise SystemExit(0 if result["ready"] else 2)


if __name__ == "__main__":
    main()
