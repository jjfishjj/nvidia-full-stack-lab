# GCP 台灣一次性 GPU Runner

這套控制層提供兩個經審核的 profile：

| Profile | 區域 | 機型 | 用途 | 工作逾時 |
|---|---|---|---|---:|
| `l4` | `asia-east1-a` | `g2-standard-4`、1×L4 24GB | 日常 CUDA、診斷、RAPIDS、單 GPU Dask | 60 分鐘 |
| `h100` | `asia-east1-c` | `a3-highgpu-8g`、8×H100 | NVLink、NCCL、多 GPU Dask | 90 分鐘 |

兩者都沒有公開 IP，透過專用 subnet 與 Cloud NAT 連到 GitHub，只註冊一次性 repository Runner。VM 設有 2 小時硬性存活上限，到時由 GCP 自動刪除；GitHub 的 `cleanup` job 也會在正常完成或失敗時刪除 VM、開機磁碟與該次 Runner token secret。

## 第一次設定（不建立 GPU VM）

1. 建立獨立且已啟用 Billing 的 GCP project，並先設定預算通知與 GPU quota。
2. 在 `bootstrap/` 複製 `terraform.tfvars.example` 為 `terraform.tfvars`，填入 project 與 repository。
3. 以有權建立 IAM 資源的管理者執行 `terraform init`、`terraform plan`，確認後才執行 `terraform apply`。
4. 把 Terraform outputs 設成 GitHub repository variables：

   - `GCP_PROJECT_ID`
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_DEPLOYER_SERVICE_ACCOUNT`
   - `GCP_RUNNER_SERVICE_ACCOUNT`

5. 建立 GitHub Environment `gcp-gpu-approval`，加入 required reviewer；H100 建議另由組織政策限制核准人。
6. 建立 fine-grained token 或 GitHub App token，權限限定此 repository 的 **Administration: write**，存成 Actions secret `GPU_RUNNER_ADMIN_TOKEN`。它只用來向 GitHub 取得一小時內有效的單次 Runner 註冊 token。
7. 確認 GCP Deep Learning VM image family。預設為 `common-cu128-ubuntu-2204-nvidia-570`；若 GCP 已更新 family，設定 `GCP_IMAGE_FAMILY` 與 `GCP_IMAGE_PROJECT` repository variables 覆寫。

## 執行

從 Actions 手動啟動 **GCP GPU full-stack baseline**：

- 第一次選 `l4`、不要勾 Spot。
- Environment 核准後才會建立 VM 並開始計費。
- L4 完整通過後，再測一次 L4 Spot。
- H100 必須先取得 A3 quota／capacity，並只在多 GPU 驗證時手動選擇。

## 防呆與事故處理

- Workflow 不接受 push 或 pull request 觸發。
- 每次 VM 都有唯一 `run-<id>-<attempt>` label，避免舊 Runner 接錯工作。
- 建立過程失敗時，腳本會嘗試移除半成品 VM 與 secret。
- Cleanup 使用 `if: always()`；VM 另有 120 分鐘關機保險。
- 測試報告會保存 Actions Runner `_diag` 與 startup log；cleanup 也會在刪除前擷取 VM serial log，避免一次性主機消失後無法稽核。
- 若 GitHub 完全中斷，請在 GCP 依 label `managed-by=github-actions` 搜尋並刪除殘留資源。
- Secret Manager、映像下載與開機準備也會產生少量費用；實際費率與容量以執行當下的 GCP Console 為準。

## 驗收順序

1. `terraform plan` 只顯示 API、兩個 service accounts、OIDC、最小必要 IAM，以及沒有 inbound 規則的專用 VPC／Cloud NAT。
2. L4 工作進入 Runner 後，`preflight.json` 顯示 1 張 L4、Docker GPU 可用。
3. 六個專案產生 JSON、`nvidia-smi -q`、topology 與 `report.md` artifact。
4. 工作結束 15 分鐘內，VM 與單次 secret 不再存在。
5. 再以 H100 profile 驗證 8 GPU 拓撲與多 GPU Dask；InfiniBand 不在本 MVP 範圍。
