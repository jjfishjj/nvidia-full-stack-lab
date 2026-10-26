# NVIDIA 實機 Runner

目標主機必須是 Linux x86_64，已安裝 NVIDIA Driver、Docker Engine、NVIDIA Container Toolkit、Python 3 與 GitHub CLI。執行前先驗證：

```bash
python3 runner/preflight.py --container-check --output preflight.json
```

確認 `ready: true` 後，以已登入且具有六個 repository 管理權限的 `gh` 執行：

```bash
sudo -v
OWNER=jjfishjj bash runner/register-runners.sh
```

腳本會為入口網站及五個 GPU 專案建立彼此隔離的 repo-level runner service。RDMA 主機偵測到 `/sys/class/infiniband` 時才加入 `infiniband` label；不會把 token 寫入 repository。

## 公開 repository 安全界線

GPU workflows 必須維持 `workflow_dispatch`，不可直接由 fork PR 執行。一般 PR 只使用 GitHub-hosted Runner。建議使用專用測試節點、最小權限帳號、無生產環境憑證，並定期更新 Runner 與作業系統。
