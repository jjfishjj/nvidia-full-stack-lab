# Local Host Preflight — 2026-10-27

| 項目 | 結果 |
|---|---|
| OS | Windows 11 Pro 64-bit |
| Display adapter | Intel UHD Graphics 620 |
| NVIDIA GPU | 未偵測 |
| `nvidia-smi` | 不可用 |
| CUDA Toolkit／`nvcc` | 不可用 |
| Docker Engine | 不可用 |
| WSL Linux distribution | 未安裝 |
| GPU Runner eligibility | 不通過 |

## 結論

此主機可以執行六個專案的 CPU 單元測試與靜態網站，但不能產生 NVIDIA CUDA、NCCL、RAPIDS 或 Dask-CUDA 實機基準。不可為它加上 `gpu` label。下一次實測應在 Linux NVIDIA 節點執行 `runner/preflight.py --container-check`，結果為 `ready: true` 後才註冊 Runner。
