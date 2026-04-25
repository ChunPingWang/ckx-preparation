#!/bin/bash
# scripts/master_setup.sh
# 僅在 Control Plane (k8s-master) 執行

set -euo pipefail
LOG="/var/log/k8s-master-setup.log"
exec > >(tee -a "$LOG") 2>&1

MASTER_IP="192.168.56.10"
POD_CIDR="192.168.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
JOIN_TOKEN_FILE="/vagrant/join_command.sh"

echo "=========================================="
echo " [master_setup.sh] 開始：$(date)"
echo "=========================================="

# ── 1. kubeadm init ─────────────────────────
echo "[Step 1] 執行 kubeadm init..."
kubeadm init \
  --apiserver-advertise-address="${MASTER_IP}" \
  --pod-network-cidr="${POD_CIDR}" \
  --service-cidr="${SERVICE_CIDR}" \
  --kubernetes-version="1.29.3" \
  --ignore-preflight-errors=NumCPU \
  2>&1 | tee /var/log/kubeadm-init.log

# ── 2. 設定 kubectl 存取 ────────────────────
echo "[Step 2] 設定 kubeconfig..."

export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# ── 3. 安裝 Calico CNI ──────────────────────
echo "[Step 3] 安裝 Calico CNI v3.27..."

kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "  等待 Calico DaemonSet 就緒（約 60 秒）..."
# 用 rollout status 取代 wait — wait 在 Pod 還沒被 controller 建立前會直接失敗（no matching resources）
kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  rollout status daemonset/calico-node -n kube-system --timeout=300s

echo "  等待 k8s-master 節點 Ready..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  wait --for=condition=Ready node/k8s-master --timeout=180s

# ── 4. 產生 Worker Join 指令並儲存 ──────────
echo "[Step 4] 產生 join 指令..."
JOIN_CMD=$(kubeadm token create --print-join-command)

cat > "${JOIN_TOKEN_FILE}" <<EOF
#!/bin/bash
# 自動產生的 Worker Join 指令 - 請勿手動修改
# 有效期限：24 小時
${JOIN_CMD}
EOF
chmod +x "${JOIN_TOKEN_FILE}"

echo "  Join 指令已儲存至：${JOIN_TOKEN_FILE}"

# ── 5. 設定 kubectl 自動補全與別名 ──────────
echo "[Step 5] 設定 kubectl 便利工具..."

sudo -u vagrant bash -c '
  echo "source <(kubectl completion bash)" >> ~/.bashrc
  echo "alias k=kubectl" >> ~/.bashrc
  echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
  echo "export do='"'"'--dry-run=client -o yaml'"'"'" >> ~/.bashrc
  echo "export now='"'"'--force --grace-period 0'"'"'" >> ~/.bashrc
'

# ── 6. 顯示叢集狀態 ─────────────────────────
echo ""
echo "=========================================="
echo " Control Plane 初始化完成！"
echo "=========================================="
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system
echo ""
echo " 下一步：Worker Node 將自動加入叢集"
echo "=========================================="
