#!/bin/bash
# scripts/pause-cluster.sh
# 在 Host 機器執行（與 Vagrantfile 同目錄）
# 暫停所有 K8s VM — vagrant suspend 將 VM 狀態 snapshot 到磁碟
# 用 ./scripts/resume-cluster.sh 復原

set -euo pipefail

# 切到 Vagrantfile 所在目錄（此腳本可以從任何位置呼叫）
cd "$(dirname "$0")/.."

NODES=("k8s-node2" "k8s-node1" "k8s-master")

echo "=========================================="
echo " [pause-cluster] 開始：$(date)"
echo "=========================================="

for node in "${NODES[@]}"; do
  echo "[pause] 暫停 ${node} ..."
  vagrant suspend "${node}"
done

echo
echo "[pause] 完成。目前狀態："
vagrant status
echo "=========================================="
echo " 復原請執行：./scripts/resume-cluster.sh"
echo "=========================================="
