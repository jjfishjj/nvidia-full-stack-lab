# NVIDIA 實驗室版本相容矩陣

更新基準：2026-10-27。正式部署前仍應依實際 GPU architecture 與 NVIDIA release notes 重驗。

| Track | GPU architecture | Driver | CUDA | RAPIDS | Python | 用途 |
|---|---|---:|---:|---:|---:|---|
| Legacy | Volta／Pascal／Maxwell | R525–R579 | 12.x | 26.08 `cuda12` | 3.12 | 保留舊卡實驗；CUDA 13 已不涵蓋這些架構 |
| Stable | Turing／Ampere／Ada／Hopper | R580+ | 13.x | 26.08 `cuda13` | 3.12 | 本專案預設 |
| Blackwell | Blackwell | R580+，依 Toolkit release notes 提升 | 13.x；最低從 12.8 開始支援 | 26.08 `cuda13` | 3.12 | 新硬體與效能驗證 |

## 固定版本

- CUDA container：`nvidia/cuda:13.4.3-*-ubuntu24.04`
- CUDA DL／NCCL container：`nvcr.io/nvidia/cuda-dl-base:26.08-cuda13.4-devel-ubuntu24.04`
- RAPIDS container：`rapidsai/base:26.08-cuda13-py3.12`
- NCCL 文件基線：2.32.3
- `nccl-tests` commit：`afd59abab774a6a4b492eb344bd0c845a0b7bb4d`
- NVIDIA Container Toolkit：1.20.1 或更新的相容正式版

## 重要規則

CUDA 13.x 的 minor-version compatibility 最低 Driver branch 為 R580；CUDA 12.x 為 R525。較新的 driver 可執行較舊 Toolkit 建置的程式，但 GPU architecture 可能在新 Toolkit 中被移除，兩者要分開判斷。RAPIDS pip wheel 後綴必須與 CUDA major 相符；需要 InfiniBand/RoCE 時不要使用不含 RDMA 的 PyPI UCX build，應採系統 UCX/HPC-X 或驗證過的容器。
