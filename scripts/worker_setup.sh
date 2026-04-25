#!/bin/bash
# scripts/worker_setup.sh
# 在 k8s-node1 與 k8s-node2 執行

set -euo pipefail
LOG="/var/log/k8s-worker-setup.log"
exec > >(tee -a "$LOG") 2>&1

JOIN_TOKEN_FILE="/vagrant/join_command.sh"
MAX_WAIT=300

echo "=========================================="
echo " [worker_setup.sh] 開始：$(date)"
echo "=========================================="

# ── 等待 Master 產生 join 指令 ──────────────
echo "[Step 1] 等待 Control Plane 就緒..."
elapsed=0
while [ ! -f "${JOIN_TOKEN_FILE}" ]; do
  if [ $elapsed -ge $MAX_WAIT ]; then
    echo "ERROR: 超時！${JOIN_TOKEN_FILE} 不存在，請檢查 master 初始化日誌"
    exit 1
  fi
  echo "  尚未就緒，等待中... (${elapsed}s/${MAX_WAIT}s)"
  sleep 10
  elapsed=$((elapsed + 10))
done

# ── 執行 join ───────────────────────────────
echo "[Step 2] 執行 kubeadm join..."
bash "${JOIN_TOKEN_FILE}"

# ── 設定 kubectl ────────────────────────────
echo "[Step 3] 設定基礎工具..."
echo "alias k='kubectl'" >> /root/.bashrc

echo "=========================================="
echo " [worker_setup.sh] 完成：$(date)"
echo " 此節點已加入叢集！"
echo "=========================================="
