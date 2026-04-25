# Kubernetes CKA 認證實戰 PoC
## Vagrant + VirtualBox + kubeadm：Control Plane × 1 ＋ Worker Node × 2

> **目標受眾**：初學者 / CKA 考試備考  
> **學習目標**：從零搭建多節點 K8s 叢集，掌握 kubeadm 流程、網路插件、RBAC 等 CKA 核心考點

---

## 目錄

> 📝 **實戰練習手冊**：完整 22 個 Lab + 2 場模擬考 → 請見 **[CKA_PRACTICE.md](./CKA_PRACTICE.md)**

1. [版本選擇說明](#1-版本選擇說明)
2. [架構總覽](#2-架構總覽)
3. [前置需求安裝](#3-前置需求安裝-host-機器)
4. [專案目錄結構](#4-專案目錄結構)
5. [Vagrantfile 說明](#5-vagrantfile)
6. [共用初始化腳本](#6-共用初始化腳本-scriptscommonsh)
7. [Control Plane 初始化](#7-control-plane-初始化-scriptsmaster_setupsh)
8. [Worker Node 加入叢集](#8-worker-node-加入叢集-scriptsworker_setupsh)
9. [啟動叢集](#9-啟動叢集)
10. [驗證叢集狀態](#10-驗證叢集狀態)
11. [外部電腦存取叢集](#11-外部電腦存取叢集)
12. [RBAC 設定實戰](#12-rbac-設定實戰)
13. [CKA 重點考點整理](#13-cka-重點考點整理)
14. [常見問題排查](#14-常見問題排查)
15. [叢集清理](#15-叢集清理)

---

## 1. 版本選擇說明

### 為什麼選這些版本？

| 元件 | 版本 | 選擇原因 |
|------|------|---------|
| **Ubuntu** | 22.04 LTS (Jammy) | LTS 長期支援、CKA 考試環境一致、套件生態成熟 |
| **VirtualBox** | 7.0.x | 跨平台穩定、與 Vagrant 整合最佳、免費 |
| **Vagrant** | 2.4.x | 支援 VirtualBox 7.0、provision 功能完整 |
| **Kubernetes** | **1.29.x** | ✅ CKA 2024-2025 官方考試版本；距 EOL 尚有餘裕 |
| **kubeadm** | 1.29.x | 與 K8s 版本一致，CKA 必考工具 |
| **containerd** | 1.7.x | K8s 官方預設 CRI（Docker shim 已移除）|
| **CNI：Calico** | 3.27.x | 支援 NetworkPolicy（CKA 考點）、效能佳 |
| **crictl** | 1.29.x | 替代 docker 指令的容器除錯工具，CKA 常用 |

> ⚠️ **重要**：CKA 考試環境以 **Kubernetes 1.29 / 1.30** 為主流，本 PoC 鎖定 **1.29** 確保與考試環境一致。  
> 考試前建議至 [training.linuxfoundation.org](https://training.linuxfoundation.org) 確認最新考試版本。

---

## 2. 架構總覽

```
┌─────────────────────────────────────────────────────────────┐
│                      Host 機器 (你的電腦)                      │
│  OS: macOS / Windows / Linux                                 │
│  軟體: VirtualBox 7.0 + Vagrant 2.4                          │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Host-Only Network: 192.168.56.0/24       │   │
│  │                                                       │   │
│  │  ┌─────────────────┐    ┌────────────┐ ┌──────────┐  │   │
│  │  │  k8s-master      │    │ k8s-node1  │ │k8s-node2 │  │   │
│  │  │  192.168.56.10   │    │192.168.56.11│ │192.168.56│  │   │
│  │  │                 │    │            │ │    .12   │  │   │
│  │  │  Control Plane: │    │  Worker 1  │ │ Worker 2 │  │   │
│  │  │  - API Server   │◄───┤            │ │          │  │   │
│  │  │  - etcd         │    │ - kubelet  │ │ - kubelet│  │   │
│  │  │  - Scheduler    │    │ - kube-    │ │ - kube-  │  │   │
│  │  │  - Controller   │    │   proxy    │ │   proxy  │  │   │
│  │  │  - kubelet      │    │ - contain- │ │ - contain│  │   │
│  │  │  - kube-proxy   │    │   erd      │ │   erd    │  │   │
│  │  │  2 CPU / 2GB RAM│    │2CPU/2GB RAM│ │2CPU/2GB  │  │   │
│  │  └─────────────────┘    └────────────┘ └──────────┘  │   │
│  │                                                       │   │
│  │         Pod Network CIDR: 192.168.0.0/16 (Calico)    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

Host 最低需求:
  CPU  : 4 核以上（建議 8 核）
  RAM  : 8 GB 以上（建議 16 GB）
  Disk : 50 GB 可用空間
```

### 各元件職責說明（CKA 考點）

| 元件 | 節點 | 功能說明 |
|------|------|---------|
| **kube-apiserver** | Master | 叢集唯一入口，所有 kubectl 指令的終點 |
| **etcd** | Master | 叢集所有狀態資料的鍵值資料庫 |
| **kube-scheduler** | Master | 決定 Pod 要排到哪個 Worker Node |
| **kube-controller-manager** | Master | 管理各種 Controller（Deployment、ReplicaSet 等）|
| **kubelet** | All | 節點代理程式，負責啟動/維護 Pod |
| **kube-proxy** | All | 管理節點的網路規則（iptables/ipvs）|
| **containerd** | All | 實際執行容器的 Container Runtime |
| **Calico** | All | Pod 網路通訊（CNI Plugin）|

---

## 3. 前置需求安裝（Host 機器）

### 3.1 安裝 VirtualBox 7.0

```bash
# macOS (使用 Homebrew)
brew install --cask virtualbox

# Ubuntu/Debian Host
wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox.gpg] \
  https://download.virtualbox.org/virtualbox/debian jammy contrib" \
  | sudo tee /etc/apt/sources.list.d/virtualbox.list

sudo apt update && sudo apt install -y virtualbox-7.0

# Windows
# 至 https://www.virtualbox.org/wiki/Downloads 下載安裝程式
```

### 3.2 安裝 Vagrant 2.4

```bash
# macOS
brew install --cask vagrant

# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
  https://apt.releases.hashicorp.com jammy main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y vagrant

# Windows
# 至 https://developer.hashicorp.com/vagrant/downloads 下載安裝程式
```

### 3.3 驗證安裝

```bash
vagrant --version    # Vagrant 2.4.x
VBoxManage --version # 7.0.x
```

---

## 4. 專案目錄結構

```
k8s-cka-poc/
├── Vagrantfile              # VM 定義：3 台機器的規格與網路
├── scripts/
│   ├── common.sh            # 所有節點共用：containerd + kubeadm 安裝
│   ├── master_setup.sh      # 僅 Control Plane：kubeadm init + Calico
│   └── worker_setup.sh      # 僅 Worker Node：等待並 join
├── manifests/               # K8s YAML 資源定義
│   ├── rbac/
│   │   ├── 01-namespace.yaml
│   │   ├── 02-serviceaccount.yaml
│   │   ├── 03-role.yaml
│   │   ├── 04-rolebinding.yaml
│   │   ├── 05-clusterrole.yaml
│   │   └── 06-clusterrolebinding.yaml
│   └── demo/
│       ├── nginx-deployment.yaml
│       └── nginx-service.yaml
└── README.md                # 本文件
```

建立目錄：

```bash
mkdir -p k8s-cka-poc/scripts k8s-cka-poc/manifests/rbac k8s-cka-poc/manifests/demo
cd k8s-cka-poc
```

---

## 5. Vagrantfile

建立 `Vagrantfile`（注意：無副檔名）：

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================================
# Kubernetes CKA PoC - Vagrantfile
# 架構: 1 Control Plane + 2 Worker Nodes
# ============================================================

Vagrant.configure("2") do |config|

  # ── 共用設定 ──────────────────────────────────────────────
  # Ubuntu 22.04 LTS 官方 Box（由 Vagrant 社群維護）
  config.vm.box              = "ubuntu/jammy64"
  config.vm.box_version      = ">= 20240101.0.0"

  # 關閉 Vagrant 自動更新 Guest Additions（避免版本不符問題）
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  # 共用 provision：每台 VM 都執行
  config.vm.provision "shell", path: "scripts/common.sh"

  # ── 節點定義 ──────────────────────────────────────────────
  nodes = [
    { name: "k8s-master", ip: "192.168.56.10", cpu: 2, mem: 2048, role: "master" },
    { name: "k8s-node1",  ip: "192.168.56.11", cpu: 2, mem: 2048, role: "worker" },
    { name: "k8s-node2",  ip: "192.168.56.12", cpu: 2, mem: 2048, role: "worker" },
  ]

  nodes.each do |node|
    config.vm.define node[:name] do |vm_config|

      # 主機名稱
      vm_config.vm.hostname = node[:name]

      # Host-Only 網路（VM 之間互通，且 Host 可連入）
      vm_config.vm.network "private_network", ip: node[:ip]

      # VirtualBox 硬體規格
      vm_config.vm.provider "virtualbox" do |vb|
        vb.name   = node[:name]
        vb.cpus   = node[:cpu]
        vb.memory = node[:mem]

        # 效能優化
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end

      # 角色專屬 provision
      if node[:role] == "master"
        vm_config.vm.provision "shell", path: "scripts/master_setup.sh"
      else
        vm_config.vm.provision "shell", path: "scripts/worker_setup.sh"
      end

    end
  end

end
```

---

## 6. 共用初始化腳本：`scripts/common.sh`

此腳本在 **全部 3 台** VM 執行，完成：
- 系統基礎設定（關 swap、載入核心模組）
- 安裝 containerd（Container Runtime）
- 安裝 kubeadm、kubelet、kubectl（固定版本 1.29）

```bash
#!/bin/bash
# scripts/common.sh
# 所有 K8s 節點的共用初始化
# 執行身份：root（Vagrant provision 預設）

set -euo pipefail   # 任何錯誤即停止，未定義變數報錯
LOG="/var/log/k8s-common-setup.log"
exec > >(tee -a "$LOG") 2>&1

K8S_VERSION="1.29"
KUBERNETES_PKG_VERSION="1.29.3-1.1"  # 精確鎖定版本

echo "=========================================="
echo " [common.sh] 開始：$(date)"
echo "=========================================="

# ── 1. 停用 swap（K8s 強制要求）─────────────────────────────
echo "[Step 1] 停用 Swap..."
swapoff -a
# 永久停用：移除 /etc/fstab 中的 swap 行
sed -i '/\bswap\b/d' /etc/fstab

# ── 2. 設定 /etc/hosts（節點互相解析）────────────────────────
echo "[Step 2] 設定 /etc/hosts..."
cat >> /etc/hosts <<EOF

# Kubernetes Cluster Nodes
192.168.56.10  k8s-master
192.168.56.11  k8s-node1
192.168.56.12  k8s-node2
EOF

# ── 3. 載入必要核心模組 ──────────────────────────────────────
echo "[Step 3] 載入核心模組..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay        # containerd 使用
br_netfilter   # 橋接網路過濾（K8s 必要）
EOF

modprobe overlay
modprobe br_netfilter

# ── 4. 設定 sysctl 網路參數 ──────────────────────────────────
echo "[Step 4] 設定 sysctl..."
cat > /etc/sysctl.d/k8s.conf <<EOF
# 讓橋接流量通過 iptables（K8s 網路必要）
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
# 允許 IP forwarding（Pod 封包路由）
net.ipv4.ip_forward = 1
EOF

sysctl --system   # 立即套用

# ── 5. 安裝 containerd ──────────────────────────────────────
echo "[Step 5] 安裝 containerd..."
apt-get update -qq
apt-get install -y -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# 新增 Docker 官方 GPG 金鑰（containerd 由 Docker 發布）
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 新增 Docker apt 來源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq containerd.io

# 產生預設設定並啟用 SystemdCgroup（kubeadm 要求）
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 啟用 SystemdCgroup：K8s 與 containerd 必須使用同一 cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "  containerd 版本：$(containerd --version)"

# ── 6. 安裝 kubeadm、kubelet、kubectl ────────────────────────
echo "[Step 6] 安裝 Kubernetes 工具 v${K8S_VERSION}..."

# 新增 K8s apt 來源（v1.29 專用 repo）
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

# 鎖定版本，防止 apt upgrade 自動升級（CKA 必備知識）
apt-mark hold kubelet kubeadm kubectl

# 啟用 kubelet（init 前會 crash-loop，屬正常現象）
systemctl enable kubelet

# ── 7. 安裝 crictl（容器 debug 工具）────────────────────────
echo "[Step 7] 安裝 crictl..."
CRICTL_VERSION="v1.29.0"
curl -fsSL "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" \
  | tar -C /usr/local/bin -xz

# 設定 crictl 使用 containerd
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

echo "=========================================="
echo " [common.sh] 完成：$(date)"
echo "=========================================="
```

---

## 7. Control Plane 初始化：`scripts/master_setup.sh`

```bash
#!/bin/bash
# scripts/master_setup.sh
# 僅在 Control Plane (k8s-master) 執行

set -euo pipefail
LOG="/var/log/k8s-master-setup.log"
exec > >(tee -a "$LOG") 2>&1

MASTER_IP="192.168.56.10"
POD_CIDR="192.168.0.0/16"     # Calico 預設 Pod 網路
SERVICE_CIDR="10.96.0.0/12"   # K8s Service ClusterIP 範圍
JOIN_TOKEN_FILE="/vagrant/join_command.sh"  # 透過 /vagrant 共享給 Worker

echo "=========================================="
echo " [master_setup.sh] 開始：$(date)"
echo "=========================================="

# ── 1. kubeadm init ─────────────────────────────────────────
# 這是 CKA 最核心的指令！
echo "[Step 1] 執行 kubeadm init..."
kubeadm init \
  --apiserver-advertise-address="${MASTER_IP}" \
  --pod-network-cidr="${POD_CIDR}" \
  --service-cidr="${SERVICE_CIDR}" \
  --kubernetes-version="1.29.3" \
  --ignore-preflight-errors=NumCPU \
  2>&1 | tee /var/log/kubeadm-init.log

# ── 2. 設定 kubectl 存取（為 root 與 vagrant 使用者）──────────
echo "[Step 2] 設定 kubeconfig..."

# root 使用者
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc

# vagrant 使用者（建議日常使用）
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# ── 3. 安裝 Calico CNI（網路插件）──────────────────────────
echo "[Step 3] 安裝 Calico CNI v3.27..."
# 無 CNI 則 CoreDNS 與節點 NotReady

kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "  等待 Calico Pod 就緒（約 60 秒）..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  wait --for=condition=ready pod \
  -l k8s-app=calico-node \
  -n kube-system \
  --timeout=180s

# ── 4. 產生 Worker Join 指令並儲存 ──────────────────────────
echo "[Step 4] 產生 join 指令..."
JOIN_CMD=$(kubeadm token create --print-join-command)

# 寫入共享目錄 /vagrant（對應 Host 的 Vagrantfile 所在目錄）
cat > "${JOIN_TOKEN_FILE}" <<EOF
#!/bin/bash
# 自動產生的 Worker Join 指令 - 請勿手動修改
# 有效期限：24 小時
${JOIN_CMD}
EOF
chmod +x "${JOIN_TOKEN_FILE}"

echo "  Join 指令已儲存至：${JOIN_TOKEN_FILE}"

# ── 5. 設定 kubectl 自動補全與別名（CKA 考試技巧）────────────
echo "[Step 5] 設定 kubectl 便利工具..."

# 為 vagrant 使用者設定
sudo -u vagrant bash -c '
  echo "source <(kubectl completion bash)" >> ~/.bashrc
  echo "alias k=kubectl" >> ~/.bashrc
  echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
  echo "export do='"'"'--dry-run=client -o yaml'"'"'" >> ~/.bashrc
  echo "export now='"'"'--force --grace-period 0'"'"'" >> ~/.bashrc
'

# ── 6. 顯示叢集狀態 ──────────────────────────────────────────
echo ""
echo "=========================================="
echo " Control Plane 初始化完成！"
echo "=========================================="
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system
echo ""
echo " 下一步：Worker Node 將自動加入叢集"
echo "=========================================="
```

---

## 8. Worker Node 加入叢集：`scripts/worker_setup.sh`

```bash
#!/bin/bash
# scripts/worker_setup.sh
# 在 k8s-node1 與 k8s-node2 執行

set -euo pipefail
LOG="/var/log/k8s-worker-setup.log"
exec > >(tee -a "$LOG") 2>&1

JOIN_TOKEN_FILE="/vagrant/join_command.sh"
MAX_WAIT=300   # 最多等待 5 分鐘（等 master 完成 init）

echo "=========================================="
echo " [worker_setup.sh] 開始：$(date)"
echo "=========================================="

# ── 等待 Master 產生 join 指令 ──────────────────────────────
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

# ── 執行 join ─────────────────────────────────────────────
echo "[Step 2] 執行 kubeadm join..."
bash "${JOIN_TOKEN_FILE}"

# ── 設定 kubectl（可選，Worker 不一定需要）──────────────────
# Worker Node 通常不設定 kubeconfig，但 debug 時有用
echo "[Step 3] 設定基礎工具..."
echo "alias k='kubectl'" >> /root/.bashrc

echo "=========================================="
echo " [worker_setup.sh] 完成：$(date)"
echo " 此節點已加入叢集！"
echo "=========================================="
```

---

## 9. 啟動叢集

### 9.1 首次建立（全自動）

```bash
cd k8s-cka-poc

# 全部啟動（順序很重要：master 必須先完成）
vagrant up k8s-master    # 先啟動 Master（約 8-12 分鐘）
vagrant up k8s-node1     # 再啟動 Worker 1（約 4-6 分鐘）
vagrant up k8s-node2     # 最後啟動 Worker 2（約 4-6 分鐘）

# 或一次啟動全部（Vagrant 按順序執行）
vagrant up
```

### 9.2 連線到各節點

```bash
# 連入 Control Plane（主要操作節點）
vagrant ssh k8s-master

# 連入 Worker Node
vagrant ssh k8s-node1
vagrant ssh k8s-node2
```

### 9.3 常用 Vagrant 操作

```bash
vagrant status           # 查看 VM 狀態
vagrant halt             # 關機（保留設定）
vagrant up               # 開機
vagrant reload           # 重啟
vagrant destroy -f       # 完全刪除（需重建）
vagrant provision        # 重新執行 provision 腳本
```

---

## 10. 驗證叢集狀態

登入 Master 節點後執行以下驗證：

```bash
vagrant ssh k8s-master
```

### 10.1 確認節點狀態

```bash
kubectl get nodes -o wide

# 預期輸出：
# NAME         STATUS   ROLES           AGE   VERSION   INTERNAL-IP      OS-IMAGE
# k8s-master   Ready    control-plane   10m   v1.29.3   192.168.56.10   Ubuntu 22.04
# k8s-node1    Ready    <none>          8m    v1.29.3   192.168.56.11   Ubuntu 22.04
# k8s-node2    Ready    <none>          8m    v1.29.3   192.168.56.12   Ubuntu 22.04
```

### 10.2 確認 System Pod 狀態

```bash
kubectl get pods -n kube-system

# 預期所有 Pod 均為 Running 或 Completed 狀態
```

### 10.3 確認 API Server 健康

```bash
kubectl cluster-info
kubectl get componentstatuses  # 查看核心元件健康狀態

# 進階：直接打 API Server
curl -k https://192.168.56.10:6443/healthz
```

### 10.4 部署測試應用

建立 `manifests/demo/nginx-deployment.yaml`：

```yaml
# manifests/demo/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: default
  labels:
    app: nginx-demo
spec:
  replicas: 3   # 會分散到 2 個 Worker Node
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: nginx-demo
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
kubectl apply -f manifests/demo/nginx-deployment.yaml

# 驗證 Pod 分散在不同節點
kubectl get pods -o wide

# 測試 Service
curl http://192.168.56.11:30080
curl http://192.168.56.12:30080
```

---

## 11. 外部電腦存取叢集

> API Server 監聽在 `192.168.56.10:6443`，這是 VirtualBox 的 **host-only network**，預設僅 Host 機器（執行 Vagrant 的這台電腦）能直接連線。  
> 以下整理兩種存取場景。

### 11.1 場景 A：從 Host 機器存取（最簡單）

`192.168.56.10` 對 Host 直接可達，安裝 `kubectl` 並複製 kubeconfig 即可：

```bash
# 在 Host 上安裝 kubectl
sudo apt install -y kubectl              # Ubuntu/Debian
# 或 macOS:    brew install kubectl
# 或 snap:     sudo snap install kubectl --classic

# 從 master 取得 admin.conf
mkdir -p ~/.kube
vagrant ssh k8s-master -c "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
chmod 600 ~/.kube/config

# 驗證
kubectl get nodes
```

API Server 憑證已內含 `192.168.56.10` 作為 SAN（Subject Alternative Name），無需任何額外設定即可連線。

---

### 11.2 場景 B：從另一台電腦（同 LAN 或遠端）存取

Host-Only Network 對 Host 以外的電腦不可達，二擇一：

#### 方法 1：SSH 隧道（推薦，無需修改 Vagrantfile）

在外部電腦執行：

```bash
# 將外部電腦的 6443 port 透過 Host 轉發到 master
ssh -L 6443:192.168.56.10:6443 <YOUR_HOST_USER>@<HOST_LAN_IP>
# 此 SSH session 維持開啟期間，隧道才有效
```

將 master 的 `admin.conf` 內容複製到外部電腦 `~/.kube/config`，並修改 `clusters[0].cluster` 區塊：

```yaml
clusters:
- cluster:
    server: https://127.0.0.1:6443        # 改為 localhost
    tls-server-name: 192.168.56.10        # 讓 TLS 仍信任既有憑證
    certificate-authority-data: <保留原值>
  name: kubernetes
```

驗證：

```bash
kubectl get nodes
```

#### 方法 2：Vagrant Port Forward（持久連線，免 SSH）

編輯 `Vagrantfile` 的 master 區塊：

```ruby
if node[:role] == "master"
  vm_config.vm.network "forwarded_port",
    guest: 6443, host: 6443, host_ip: "0.0.0.0"
  vm_config.vm.provision "shell", path: "scripts/master_setup.sh"
else
  vm_config.vm.provision "shell", path: "scripts/worker_setup.sh"
end
```

執行 `vagrant reload k8s-master`。從外部電腦：

```yaml
clusters:
- cluster:
    server: https://<HOST_LAN_IP>:6443
    tls-server-name: 192.168.56.10        # 必填，避免 cert 名稱不符
    certificate-authority-data: <保留原值>
  name: kubernetes
```

> ⚠️ API Server 憑證**未包含** Host 的 LAN IP；務必設 `tls-server-name: 192.168.56.10`，否則需加 `insecure-skip-tls-verify: true`（僅測試環境使用）。

#### 進階：讓多個 IP 直接被信任（重新簽憑證）

若要長期讓 LAN IP 或自訂域名直接連線而不靠 `tls-server-name`，可重新 init master 並擴充 SAN：

```bash
# 在 master 上（會清除現有叢集）
sudo kubeadm reset -f
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.10 \
  --apiserver-cert-extra-sans=<HOST_LAN_IP>,localhost,127.0.0.1,my.cluster.local \
  --pod-network-cidr=192.168.0.0/16 \
  --kubernetes-version=1.29.3
```

> 練習用建議使用 **方法 1 SSH 隧道**：最簡單、可隨時關閉、無需重啟 VM。

---

## 12. RBAC 設定實戰

> **RBAC（Role-Based Access Control）** 是 CKA 的高頻考點！  
> 核心概念：**Who（SA/User）** 透過 **RoleBinding/ClusterRoleBinding** 取得 **Role/ClusterRole** 所定義的 **What（API 操作權限）**

### 11.1 RBAC 核心資源關係圖

```
                    ┌──────────────────────────────────┐
                    │           Scope 比較               │
                    │                                   │
  Namespace 範圍 ──►│  Role           RoleBinding       │
                    │  (可做什麼?)     (誰能做?)         │
                    │                                   │
  Cluster 範圍 ────►│  ClusterRole    ClusterRoleBinding│
                    │                                   │
                    └──────────────────────────────────┘

  主體（Subject）種類：
  ┌──────────────────┬──────────────────────────────────┐
  │ ServiceAccount   │ K8s 內部身份（Pod 使用）           │
  │ User             │ 外部使用者（kubeconfig 中的 user） │
  │ Group            │ 使用者群組                        │
  └──────────────────┴──────────────────────────────────┘
```

### 11.2 Namespace 建立

建立 `manifests/rbac/01-namespace.yaml`：

```yaml
# manifests/rbac/01-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev        # 開發環境命名空間
  labels:
    env: development
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod       # 生產環境命名空間
  labels:
    env: production
```

### 11.3 ServiceAccount 建立

建立 `manifests/rbac/02-serviceaccount.yaml`：

```yaml
# manifests/rbac/02-serviceaccount.yaml
# ServiceAccount 是 Pod 的身份識別
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-developer    # 開發者帳號
  namespace: dev
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-readonly     # 唯讀帳號（如 QA 人員）
  namespace: dev
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-deployer    # CI/CD 系統部署帳號
  namespace: dev
```

### 11.4 Role 定義（Namespace 範圍）

建立 `manifests/rbac/03-role.yaml`：

```yaml
# manifests/rbac/03-role.yaml
# Role 定義在特定 Namespace 內可做哪些操作

# 開發者：可操作大部分資源
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: dev
rules:
  # Pod 管理（查、建、刪）
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec"]
    verbs: ["get", "list", "watch", "create", "delete"]
  # Deployment 管理
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # Service 管理
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # ConfigMap 管理
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
# 唯讀者：只能看，不能改
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly-role
  namespace: dev
rules:
  - apiGroups: ["", "apps", "batch"]
    resources:
      - pods
      - pods/log
      - deployments
      - replicasets
      - services
      - configmaps
      - jobs
    verbs: ["get", "list", "watch"]   # 只允許讀取
---
# CI/CD 部署者：只能更新 Deployment image
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deploy-role
  namespace: dev
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### 11.5 RoleBinding（將 Role 綁給 ServiceAccount）

建立 `manifests/rbac/04-rolebinding.yaml`：

```yaml
# manifests/rbac/04-rolebinding.yaml
# RoleBinding 將 Role 與 Subject（SA/User/Group）綁定

# 將 developer-role 綁給 dev-developer ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-rolebinding
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: dev-developer
    namespace: dev
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
---
# 將 readonly-role 綁給 dev-readonly ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-rolebinding
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: dev-readonly
    namespace: dev
roleRef:
  kind: Role
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
---
# 將 cicd-deploy-role 綁給 cicd-deployer ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deploy-rolebinding
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: cicd-deployer
    namespace: dev
roleRef:
  kind: Role
  name: cicd-deploy-role
  apiGroup: rbac.authorization.k8s.io
```

### 11.6 ClusterRole（跨 Namespace 範圍）

建立 `manifests/rbac/05-clusterrole.yaml`：

```yaml
# manifests/rbac/05-clusterrole.yaml
# ClusterRole 作用於整個叢集（所有 Namespace）

# 叢集監控者：可查看所有節點、所有 Namespace 的 Pod
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-monitor-role
rules:
  # 節點資訊（只有 ClusterRole 能存取，無 namespace）
  - apiGroups: [""]
    resources: ["nodes", "nodes/metrics", "nodes/stats"]
    verbs: ["get", "list", "watch"]
  # 所有 Namespace 的 Pod 查看
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  # Namespace 清單
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
  # PersistentVolume（叢集級儲存）
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch"]
---
# 儲存管理員：可管理 PV/PVC/StorageClass
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-admin-role
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### 11.7 ClusterRoleBinding

建立 `manifests/rbac/06-clusterrolebinding.yaml`：

```yaml
# manifests/rbac/06-clusterrolebinding.yaml
# ClusterRoleBinding 讓 Subject 取得叢集級別權限

# 叢集監控 ServiceAccount（放在 monitoring 或 default namespace）
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-monitor
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-monitor-binding
subjects:
  - kind: ServiceAccount
    name: cluster-monitor
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-monitor-role
  apiGroup: rbac.authorization.k8s.io
---
# 進階用法：ClusterRole 搭配 RoleBinding（限制在特定 Namespace）
# 讓 dev-developer 使用 cluster-monitor-role，但只在 dev namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-monitor-rolebinding
  namespace: dev         # ← 此 RoleBinding 限制在 dev namespace
subjects:
  - kind: ServiceAccount
    name: dev-developer
    namespace: dev
roleRef:
  kind: ClusterRole      # ← 引用 ClusterRole
  name: cluster-monitor-role
  apiGroup: rbac.authorization.k8s.io
```

### 11.8 套用所有 RBAC 設定

```bash
# 套用全部 RBAC 資源（在 k8s-master 上執行）
kubectl apply -f manifests/rbac/

# 確認建立結果
kubectl get namespace dev prod
kubectl get serviceaccount -n dev
kubectl get role,rolebinding -n dev
kubectl get clusterrole | grep -E "cluster-monitor|storage-admin"
kubectl get clusterrolebinding | grep cluster-monitor
```

### 11.9 RBAC 驗證指令（CKA 高頻指令）

```bash
# ── auth can-i：最直接的權限驗證方式 ────────────────────────

# 以 dev-developer 身份，測試在 dev namespace 能否 list pods
kubectl auth can-i list pods \
  --namespace=dev \
  --as=system:serviceaccount:dev:dev-developer

# 以 dev-readonly 身份，測試能否 delete pods（應為 no）
kubectl auth can-i delete pods \
  --namespace=dev \
  --as=system:serviceaccount:dev:dev-readonly

# 以 cicd-deployer 身份，測試能否 update deployments
kubectl auth can-i update deployments \
  --namespace=dev \
  --as=system:serviceaccount:dev:cicd-deployer

# 測試跨 namespace：dev-developer 能否在 prod namespace 操作？（應為 no）
kubectl auth can-i list pods \
  --namespace=prod \
  --as=system:serviceaccount:dev:dev-developer

# ── 查看 Subject 的所有權限（K8s 1.26+ 支援）────────────────
kubectl auth can-i --list \
  --namespace=dev \
  --as=system:serviceaccount:dev:dev-developer

# ── 快速建立 Role 的 imperative 方式（CKA 考試技巧）─────────
# 考試中用 kubectl create 比寫 YAML 快很多！

# 建立 Role
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --namespace=dev

# 建立 ClusterRole
kubectl create clusterrole node-reader \
  --verb=get,list,watch \
  --resource=nodes

# 建立 RoleBinding
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=dev:dev-readonly \
  --namespace=dev

# 建立 ClusterRoleBinding
kubectl create clusterrolebinding node-reader-binding \
  --clusterrole=node-reader \
  --serviceaccount=kube-system:cluster-monitor

# ── 使用 --dry-run 預覽 YAML（考試技巧）───────────────────────
kubectl create role test-role \
  --verb=get,list \
  --resource=pods \
  --namespace=dev \
  --dry-run=client -o yaml   # 不實際建立，只輸出 YAML
```

---

## 13. CKA 重點考點整理

### 12.1 叢集架構與安裝（25%）

```bash
# ── kubeadm 常用指令 ──────────────────────────────────────

# 查看目前叢集設定
kubectl config view

# 查看 kubeadm 設定
kubeadm config print init-defaults

# 升級叢集版本（CKA 必考！）
# Step 1：先升 Control Plane
kubeadm upgrade plan                    # 查看可升級版本
kubeadm upgrade apply v1.30.0          # 執行升級

# Step 2：升 kubelet & kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# Step 3：升 Worker Node（每台都要）
kubectl drain k8s-node1 --ignore-daemonsets --delete-emptydir-data
# 在 node1 上執行 apt-get upgrade 後...
kubectl uncordon k8s-node1

# ── etcd 備份與還原（CKA 必考！）──────────────────────────
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 驗證備份
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-out=table

# 還原 etcd
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore

# 修改 /etc/kubernetes/manifests/etcd.yaml 指向新的 data-dir
```

### 12.2 工作負載管理（15%）

```bash
# ── Deployment 操作 ───────────────────────────────────────
kubectl create deployment nginx \
  --image=nginx:1.25 --replicas=3 --dry-run=client -o yaml

# 滾動更新（Rolling Update）
kubectl set image deployment/nginx-demo nginx=nginx:1.26-alpine

# 查看更新狀態
kubectl rollout status deployment/nginx-demo

# 回滾（Rollback）
kubectl rollout undo deployment/nginx-demo
kubectl rollout undo deployment/nginx-demo --to-revision=2

# 暫停/恢復更新
kubectl rollout pause deployment/nginx-demo
kubectl rollout resume deployment/nginx-demo

# ── 水平擴縮（HPA）─────────────────────────────────────────
kubectl scale deployment nginx-demo --replicas=5
kubectl autoscale deployment nginx-demo --min=2 --max=10 --cpu-percent=70
```

### 12.3 排程（Scheduling）（15%）

```yaml
# nodeSelector：選擇特定節點
spec:
  nodeSelector:
    kubernetes.io/hostname: k8s-node1

# nodeName：直接指定節點（最高優先）
spec:
  nodeName: k8s-node1

# Taints & Tolerations（CKA 必考）
# 為節點加 Taint
# kubectl taint nodes k8s-node1 env=prod:NoSchedule

# Pod 設定 Toleration
spec:
  tolerations:
  - key: "env"
    operator: "Equal"
    value: "prod"
    effect: "NoSchedule"

# Affinity / Anti-Affinity
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values: ["nginx-demo"]
          topologyKey: kubernetes.io/hostname
```

```bash
# 查看節點 Taint
kubectl describe node k8s-node1 | grep Taint

# 加 / 移除 Taint
kubectl taint nodes k8s-node1 env=prod:NoSchedule
kubectl taint nodes k8s-node1 env=prod:NoSchedule-   # 加 - 表示移除

# 查看 Pod 排程原因
kubectl describe pod <pod-name> | grep -A 5 Events
```

### 12.4 儲存（Storage）（10%）

```yaml
# PersistentVolume (PV) - 叢集管理員建立
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-demo
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce      # RWO：單節點讀寫
    # - ReadOnlyMany     # ROX：多節點唯讀
    # - ReadWriteMany    # RWX：多節點讀寫（NFS 等）
  persistentVolumeReclaimPolicy: Retain  # 釋放後保留資料
  hostPath:
    path: /data/pv-demo  # 測試用，生產不建議
---
# PersistentVolumeClaim (PVC) - 開發者申請
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo
  namespace: dev
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
# 查看 PV/PVC 狀態
kubectl get pv,pvc -A

# PVC 狀態說明：
# Pending  - 尚未綁定到 PV
# Bound    - 已綁定
# Released - PVC 刪除後，PV 等待回收
```

### 12.5 網路（Networking）（20%）

```bash
# ── Service 類型 ──────────────────────────────────────────
# ClusterIP（叢集內部，預設）
kubectl expose deployment nginx-demo --port=80 --type=ClusterIP

# NodePort（對外，port 30000-32767）
kubectl expose deployment nginx-demo --port=80 --type=NodePort --node-port=30080

# ── NetworkPolicy（CKA 必考）──────────────────────────────
```

```yaml
# 預設拒絕所有 ingress 流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: dev
spec:
  podSelector: {}      # 空 selector = 選取所有 Pod
  policyTypes:
  - Ingress            # 只限制入站流量

---
# 只允許特定 Label 的 Pod 進入
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend    # 只允許 frontend Pod 存取 backend
    ports:
    - protocol: TCP
      port: 8080
```

### 12.6 故障排查（Troubleshooting）（30%）

```bash
# ── Pod 排查 ──────────────────────────────────────────────
kubectl describe pod <pod-name>             # 查看事件（Events）
kubectl logs <pod-name>                    # 查看日誌
kubectl logs <pod-name> -c <container>     # 多容器 Pod 指定 container
kubectl logs <pod-name> --previous         # 上次崩潰的日誌

# 進入 Pod 除錯
kubectl exec -it <pod-name> -- bash
kubectl exec -it <pod-name> -c <container> -- sh

# ── 節點排查 ──────────────────────────────────────────────
kubectl describe node k8s-node1            # 查看節點詳情
kubectl top nodes                          # 資源使用（需 metrics-server）
kubectl top pods -n dev

# 在節點上排查
ssh vagrant@192.168.56.11
systemctl status kubelet                   # kubelet 狀態
journalctl -u kubelet -f                   # kubelet 即時日誌
crictl ps                                  # 查看容器（代替 docker ps）
crictl logs <container-id>                 # 容器日誌
crictl pods                                # 查看所有 Pod

# ── 元件排查 ──────────────────────────────────────────────
# Control Plane 元件是 Static Pod，設定在：
ls /etc/kubernetes/manifests/
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

# 修改後 kubelet 自動重啟（無需 kubectl apply）

# ── 常見狀態說明 ──────────────────────────────────────────
# Pending        - 等待排程或資源不足
# ContainerCreating - 正在拉取映像或建立容器
# Running        - 正常運行
# CrashLoopBackOff  - 容器反覆崩潰（查 logs --previous）
# OOMKilled      - 記憶體不足被殺（調高 limits）
# Evicted        - 節點資源不足被驅逐
# ImagePullBackOff  - 映像拉取失敗（查 image 名稱或 registry）
```

### 12.7 CKA 考試必備技巧

```bash
# 1. 善用 alias 和 dry-run（考試前必設定）
alias k=kubectl
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
source <(kubectl completion bash)

# 2. 快速產生 YAML template
k run nginx --image=nginx $do > pod.yaml                          # Pod
k create deploy nginx --image=nginx $do > deploy.yaml             # Deployment
k create job myjob --image=busybox $do -- echo hello > job.yaml   # Job
k create cronjob mycron --image=busybox --schedule="*/1 * * * *" $do > cronjob.yaml

# 3. 快速刪除 Pod（不等 graceful shutdown）
k delete pod <pod-name> $now

# 4. 切換 context（多叢集考試環境）
kubectl config get-contexts
kubectl config use-context <context-name>
kubectl config current-context

# 5. 查看 API 資源簡稱
kubectl api-resources | grep -E "deploy|svc|ing|pvc|cm|secret"
# po=pods, deploy=deployments, svc=services
# ing=ingress, pvc=persistentvolumeclaims
# cm=configmaps, sa=serviceaccounts

# 6. 善用 -A 查看所有 namespace
kubectl get pods -A                    # 所有 namespace 的 Pod
kubectl get pods -A | grep -v Running  # 找出非 Running 的 Pod

# 7. jsonpath 輸出（常考）
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{.items[0].status.podIP}'
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP
```

---

## 14. 常見問題排查

### Q1：Node 狀態為 NotReady

```bash
# 在問題節點上執行
systemctl status kubelet
journalctl -u kubelet --no-pager -n 50

# 常見原因：
# 1. CNI 未安裝（執行 kubeadm init 後忘記裝 Calico）
# 2. containerd 未啟動 → systemctl restart containerd
# 3. swap 未關閉 → swapoff -a
```

### Q2：kubeadm init 失敗

```bash
# 查看詳細錯誤
kubeadm init --v=5 2>&1 | tail -50

# 重置後重試
kubeadm reset -f
rm -rf /etc/kubernetes /var/lib/etcd
kubeadm init ...
```

### Q3：Worker 無法 join

```bash
# Token 過期（預設 24 小時）→ 重新產生
kubeadm token create --print-join-command

# 確認 master 6443 port 可達
nc -zv 192.168.56.10 6443
```

### Q4：Pod 無法跨節點通訊

```bash
# Calico 未正常運行
kubectl get pods -n kube-system | grep calico

# 確認 BGP peering（Calico debug）
kubectl exec -n kube-system -it <calico-node-pod> \
  -- calico-node -bird-ready
```

### Q5：RBAC 權限不生效

```bash
# 確認 RoleBinding 綁定對象正確
kubectl describe rolebinding developer-rolebinding -n dev

# 重新測試
kubectl auth can-i list pods -n dev \
  --as=system:serviceaccount:dev:dev-developer
```

---

## 15. 叢集清理

```bash
# 方式 1：暫停（保留所有設定，下次 vagrant up 繼續）
vagrant halt

# 方式 2：完全銷毀（需重新 vagrant up 重建）
vagrant destroy -f

# 方式 3：只重置 K8s（不刪 VM）
vagrant ssh k8s-master
  sudo kubeadm reset -f
  sudo rm -rf /etc/kubernetes /var/lib/etcd $HOME/.kube

vagrant ssh k8s-node1
  sudo kubeadm reset -f

vagrant ssh k8s-node2
  sudo kubeadm reset -f
```

---

## 附錄：快速參考卡（考試用）

```
┌─────────────────────────────────────────────────────────────┐
│                    CKA 快速參考卡                             │
├─────────────────┬───────────────────────────────────────────┤
│ Pod             │ k run NAME --image=IMG                    │
│ Deployment      │ k create deploy NAME --image=IMG --replicas=N│
│ Service         │ k expose deploy NAME --port=P --type=TYPE │
│ ConfigMap       │ k create cm NAME --from-literal=K=V       │
│ Secret          │ k create secret generic NAME --from-literal=K=V│
│ ServiceAccount  │ k create sa NAME -n NS                    │
│ Role            │ k create role R --verb=V --resource=RES   │
│ RoleBinding     │ k create rolebinding RB --role=R --sa=NS:SA│
│ ClusterRole     │ k create clusterrole CR --verb=V --resource=RES│
│ ClusterRoleBinding│k create clusterrolebinding CRB --clusterrole=CR --sa=NS:SA│
├─────────────────┼───────────────────────────────────────────┤
│ 查看權限        │ k auth can-i VERB RES --as=system:serviceaccount:NS:SA│
│ 列出所有資源    │ k api-resources                           │
│ 查 Pod 日誌     │ k logs POD [-c CONTAINER] [--previous]   │
│ 進入 Pod        │ k exec -it POD -- bash                   │
│ 節點排水        │ k drain NODE --ignore-daemonsets          │
│ 節點恢復        │ k uncordon NODE                           │
│ ETCD 備份       │ etcdctl snapshot save FILE --endpoints=... │
└─────────────────┴───────────────────────────────────────────┘
```

---

*文件版本：v1.0 | Kubernetes 1.29 | 最後更新：2024*  
*參考資料：[kubernetes.io/docs](https://kubernetes.io/docs) | [killer.sh](https://killer.sh) CKA 模擬考試*

---

> 🎯 準備好了嗎？前往 **[CKA_PRACTICE.md](./CKA_PRACTICE.md)** 開始 22 個 Lab 練習！
