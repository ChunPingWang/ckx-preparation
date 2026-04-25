#!/bin/bash
# scripts/resume-cluster.sh
# 在 Host 機器執行
# 復原所有 K8s VM — 順序：master 先（API Server 必須先就緒），workers 後
# 與 pause-cluster.sh 配對

set -euo pipefail

cd "$(dirname "$0")/.."

WORKERS=("k8s-node1" "k8s-node2")

echo "=========================================="
echo " [resume-cluster] 開始：$(date)"
echo "=========================================="

# ── 1. 先復原 Control Plane ─────────────────
echo "[resume] 復原 Control Plane (k8s-master) ..."
vagrant resume k8s-master

# ── 2. 等待 API Server 就緒 ─────────────────
echo "[resume] 等待 API Server 回應（最多 90 秒）..."
ready=false
for i in $(seq 1 18); do
  if vagrant ssh k8s-master -c \
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get --raw=/healthz" \
      >/dev/null 2>&1; then
    echo "  ✓ API Server 已就緒（耗時 $((i*5)) 秒）"
    ready=true
    break
  fi
  sleep 5
done

if [ "$ready" = false ]; then
  echo "  ⚠ API Server 90 秒內未就緒，仍繼續復原 Worker（kubelet 會自動重連）"
fi

# ── 3. 復原 Workers ─────────────────────────
for node in "${WORKERS[@]}"; do
  echo "[resume] 復原 ${node} ..."
  vagrant resume "${node}"
done

# ── 4. 驗證叢集狀態 ─────────────────────────
echo
echo "[resume] 等待節點 Ready（最多 60 秒）..."
sleep 5
vagrant ssh k8s-master -c \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=Ready nodes --all --timeout=60s" \
  || echo "  ⚠ 部分節點尚未 Ready，請稍候再執行 kubectl get nodes 確認"

echo
echo "[resume] 完成。最終狀態："
vagrant ssh k8s-master -c \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"
echo "=========================================="
