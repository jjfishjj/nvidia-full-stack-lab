# NVIDIA Full-Stack Lab

一個以繁體中文呈現的 NVIDIA GPU 加速全棧知識網站，將內容拆成六個可實作的專案：

1. CUDA 資料駐留實驗室
2. GPU 拓撲與系統診斷台
3. BasePOD／SuperPOD 設計工作坊
4. RDMA 與 NCCL 網路實驗室
5. RAPIDS GPU-native 資料管線
6. Dask 多 GPU 擴展挑戰

## 本機預覽

直接開啟 `index.html`，或用任一靜態網站伺服器啟動此目錄。

## GitHub Pages

推送到 GitHub 後，`Deploy static site to Pages` workflow 會自動發布 `main` 分支內容。請在儲存庫 Settings → Pages → Source 選擇 **GitHub Actions**。

## NVIDIA 實機驗證

- [`runner/`](runner/)：Linux NVIDIA 主機預檢、repo-level Runner 安裝及完整基準報告產生器。
- [`COMPATIBILITY.md`](COMPATIBILITY.md)：Driver、CUDA、GPU architecture、RAPIDS、NCCL 與 Python 相容矩陣。
- `NVIDIA full-stack baseline` workflow：在自架 GPU Runner 上依序執行六個專案並上傳 Markdown／JSON／拓撲報告。

本機目前只偵測到 Intel UHD 620，因此不具備 GPU 實測條件；請在 NVIDIA Linux 節點執行 `runner/preflight.py`，通過後再註冊 Runner。

本網站為獨立教育用途，NVIDIA 產品名稱為 NVIDIA Corporation 的商標。
