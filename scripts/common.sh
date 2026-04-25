#!/bin/bash
# scripts/common.sh
# 所有 K8s 節點的共用初始化
# 執行身份：root（Vagrant provision 預設）

set -euo pipefail
LOG="/var/log/k8s-common-setup.log"
exec > >(tee -a "$LOG") 2>&1

K8S_VERSION="1.29"
KUBERNETES_PKG_VERSION="1.29.3-1.1"

echo "=========================================="
echo " [common.sh] 開始：$(date)"
echo "=========================================="

# ── 1. 停用 swap ─────────────────────────────
echo "[Step 1] 停用 Swap..."
swapoff -a
sed -i '/\bswap\b/d' /etc/fstab

# ── 2. 設定 /etc/hosts ───────────────────────
echo "[Step 2] 設定 /etc/hosts..."
cat >> /etc/hosts <<EOF

# Kubernetes Cluster Nodes
192.168.56.10  k8s-master
192.168.56.11  k8s-node1
192.168.56.12  k8s-node2
EOF

# ── 3. 載入必要核心模組 ──────────────────────
echo "[Step 3] 載入核心模組..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ── 4. 設定 sysctl 網路參數 ──────────────────
echo "[Step 4] 設定 sysctl..."
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# ── 5. 安裝 containerd ───────────────────────
echo "[Step 5] 安裝 containerd..."
apt-get update -qq
apt-get install -y -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq containerd.io

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "  containerd 版本：$(containerd --version)"

# ── 6. 安裝 kubeadm、kubelet、kubectl ────────
echo "[Step 6] 安裝 Kubernetes 工具 v${K8S_VERSION}..."

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq \
  kubelet="${KUBERNETES_PKG_VERSION}" \
  kubeadm="${KUBERNETES_PKG_VERSION}" \
  kubectl="${KUBERNETES_PKG_VERSION}"

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

# ── 7. 安裝 crictl ───────────────────────────
echo "[Step 7] 安裝 crictl..."
CRICTL_VERSION="v1.29.0"
curl -fsSL "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" \
  | tar -C /usr/local/bin -xz

cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

echo "=========================================="
echo " [common.sh] 完成：$(date)"
echo "=========================================="
