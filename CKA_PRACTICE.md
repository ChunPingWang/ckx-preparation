# CKA 認證實戰練習手冊

> **對應考試比重**（2024-2025 CKA 官方課綱）  
> 每個 Lab 標示難度 🟢 Easy｜🟡 Medium｜🔴 Hard 與對應考域百分比

```
考域分布：
┌────────────────────────────────────────────────┬──────┐
│ Cluster Architecture, Installation & Config    │  25% │
│ Workloads & Scheduling                         │  15% │
│ Services & Networking                          │  20% │
│ Storage                                        │  10% │
│ Troubleshooting                                │  30% │
└────────────────────────────────────────────────┴──────┘
```

---

## 目錄

### 叢集架設篇（Vagrant + VirtualBox + kubeadm）
- [版本選擇說明](#版本選擇說明)
- [架構總覽](#架構總覽)
- [前置需求安裝](#前置需求安裝host-機器)
- [專案目錄結構](#專案目錄結構)
- [Vagrantfile 說明](#vagrantfile)
- [共用初始化腳本](#共用初始化腳本scriptscommonsh)
- [Control Plane 初始化](#control-plane-初始化scriptsmaster_setupsh)
- [Worker Node 加入叢集](#worker-node-加入叢集scriptsworker_setupsh)
- [啟動叢集](#啟動叢集)
- [驗證叢集狀態](#驗證叢集狀態)
- [外部電腦存取叢集](#外部電腦存取叢集)
- [RBAC 設定實戰](#rbac-設定實戰)
- [CKA 重點考點整理](#cka-重點考點整理)
- [常見問題排查](#常見問題排查)
- [叢集生命週期管理](#叢集生命週期管理)

### Domain 1：叢集架構、安裝與設定（25%）
- [Lab 01 🟡 etcd 備份與還原](#lab-01-etcd-備份與還原)
- [Lab 02 🔴 叢集版本升級](#lab-02-叢集版本升級)
- [Lab 03 🟢 節點維護：Drain & Uncordon](#lab-03-節點維護drain--uncordon)
- [Lab 04 🟡 kubeconfig 管理與多叢集切換](#lab-04-kubeconfig-管理與多叢集切換)
- [Lab 05 🟡 RBAC 綜合練習](#lab-05-rbac-綜合練習)

### Domain 2：工作負載與排程（15%）
- [Lab 06 🟢 Deployment 全操作](#lab-06-deployment-全操作)
- [Lab 07 🟡 排程控制：Taint、Toleration、Affinity](#lab-07-排程控制tainttolerationaffinity)
- [Lab 08 🟡 DaemonSet 與 StaticPod](#lab-08-daemonset-與-staticpod)
- [Lab 09 🟢 ConfigMap 與 Secret](#lab-09-configmap-與-secret)
- [Lab 10 🟡 多容器 Pod：Init、Sidecar](#lab-10-多容器-pod-initsidecar)
- [Lab 11 🟡 Job 與 CronJob](#lab-11-job-與-cronjob)

### Domain 3：服務與網路（20%）
- [Lab 12 🟢 Service 四種類型實作](#lab-12-service-四種類型實作)
- [Lab 13 🟡 NetworkPolicy 流量管控](#lab-13-networkpolicy-流量管控)
- [Lab 14 🟡 Ingress 設定](#lab-14-ingress-設定)
- [Lab 15 🟢 DNS 與 CoreDNS 排查](#lab-15-dns-與-coredns-排查)

### Domain 4：儲存（10%）
- [Lab 16 🟡 PV / PVC / StorageClass](#lab-16-pv--pvc--storageclass)
- [Lab 17 🟢 Volume 類型：emptyDir、hostPath、configMap](#lab-17-volume-類型emptydirhostpathconfigmap)

### Domain 5：故障排查（30%）
- [Lab 18 🟡 Pod 故障排查](#lab-18-pod-故障排查)
- [Lab 19 🔴 節點故障排查](#lab-19-節點故障排查)
- [Lab 20 🔴 Control Plane 元件修復](#lab-20-control-plane-元件修復)
- [Lab 21 🟡 網路故障排查](#lab-21-網路故障排查)
- [Lab 22 🟡 Log 分析與監控](#lab-22-log-分析與監控)

### 綜合模擬
- [Mock Exam 01：45 分鐘模擬考](#mock-exam-01)
- [Mock Exam 02：45 分鐘模擬考](#mock-exam-02)

---

# 叢集架設篇

> 本篇適用於 **Vagrant + VirtualBox** 方案（x86 / Intel Mac）。  
> Mac ARM (Apple Silicon) 使用者請參考 [README.md](./README.md) 的 Kind 方案。

---

## 版本選擇說明

### 為什麼選這些版本？

| 元件 | 版本 | 選擇原因 |
|------|------|---------|
| **Ubuntu** | 22.04 LTS (Jammy) | LTS 長期支援、CKA 考試環境一致、套件生態成熟 |
| **VirtualBox** | 7.0.x | 跨平台穩定、與 Vagrant 整合最佳、免費 |
| **Vagrant** | 2.4.x | 支援 VirtualBox 7.0、provision 功能完整 |
| **Kubernetes** | **1.29.x** | CKA 2024-2025 官方考試版本；距 EOL 尚有餘裕 |
| **kubeadm** | 1.29.x | 與 K8s 版本一致，CKA 必考工具 |
| **containerd** | 1.7.x | K8s 官方預設 CRI（Docker shim 已移除）|
| **CNI：Calico** | 3.27.x | 支援 NetworkPolicy（CKA 考點）、效能佳 |
| **crictl** | 1.29.x | 替代 docker 指令的容器除錯工具，CKA 常用 |

> **重要**：CKA 考試環境以 **Kubernetes 1.29 / 1.30** 為主流，本 PoC 鎖定 **1.29** 確保與考試環境一致。  
> 考試前建議至 [training.linuxfoundation.org](https://training.linuxfoundation.org) 確認最新考試版本。

---

## 架構總覽

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

## 前置需求安裝（Host 機器）

### 安裝 VirtualBox 7.0

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

### 安裝 Vagrant 2.4

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

### 驗證安裝

```bash
vagrant --version    # Vagrant 2.4.x
VBoxManage --version # 7.0.x
```

---

## 專案目錄結構

```
k8s-cka-poc/
├── Vagrantfile              # VM 定義：3 台機器的規格與網路
├── scripts/
│   ├── common.sh            # 所有節點共用：containerd + kubeadm 安裝（VM 內執行）
│   ├── master_setup.sh      # 僅 Control Plane：kubeadm init + Calico（VM 內執行）
│   ├── worker_setup.sh      # 僅 Worker Node：等待並 join（VM 內執行）
│   ├── pause-cluster.sh     # Host 端：vagrant suspend 全部 VM
│   └── resume-cluster.sh    # Host 端：依正確順序 vagrant resume + 等待 API Server
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
└── README.md
```

建立目錄：

```bash
mkdir -p k8s-cka-poc/scripts k8s-cka-poc/manifests/rbac k8s-cka-poc/manifests/demo
cd k8s-cka-poc
```

---

## Vagrantfile

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

## 共用初始化腳本：`scripts/common.sh`

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

## Control Plane 初始化：`scripts/master_setup.sh`

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

## Worker Node 加入叢集：`scripts/worker_setup.sh`

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

## 啟動叢集

### 首次建立（全自動）

```bash
cd k8s-cka-poc

# 全部啟動（順序很重要：master 必須先完成）
vagrant up k8s-master    # 先啟動 Master（約 8-12 分鐘）
vagrant up k8s-node1     # 再啟動 Worker 1（約 4-6 分鐘）
vagrant up k8s-node2     # 最後啟動 Worker 2（約 4-6 分鐘）

# 或一次啟動全部（Vagrant 按順序執行）
vagrant up
```

### 連線到各節點

```bash
# 連入 Control Plane（主要操作節點）
vagrant ssh k8s-master

# 連入 Worker Node
vagrant ssh k8s-node1
vagrant ssh k8s-node2
```

### 常用 Vagrant 操作

```bash
vagrant status           # 查看 VM 狀態
vagrant halt             # 關機（保留設定）
vagrant up               # 開機
vagrant reload           # 重啟
vagrant destroy -f       # 完全刪除（需重建）
vagrant provision        # 重新執行 provision 腳本
```

---

## 驗證叢集狀態

登入 Master 節點後執行以下驗證：

```bash
vagrant ssh k8s-master
```

### 確認節點狀態

```bash
kubectl get nodes -o wide

# 預期輸出：
# NAME         STATUS   ROLES           AGE   VERSION   INTERNAL-IP      OS-IMAGE
# k8s-master   Ready    control-plane   10m   v1.29.3   192.168.56.10   Ubuntu 22.04
# k8s-node1    Ready    <none>          8m    v1.29.3   192.168.56.11   Ubuntu 22.04
# k8s-node2    Ready    <none>          8m    v1.29.3   192.168.56.12   Ubuntu 22.04
```

### 確認 System Pod 狀態

```bash
kubectl get pods -n kube-system

# 預期所有 Pod 均為 Running 或 Completed 狀態
```

### 確認 API Server 健康

```bash
kubectl cluster-info
kubectl get componentstatuses  # 查看核心元件健康狀態

# 進階：直接打 API Server
curl -k https://192.168.56.10:6443/healthz
```

### 部署測試應用

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

## 外部電腦存取叢集

> API Server 監聽在 `192.168.56.10:6443`，這是 VirtualBox 的 **host-only network**，預設僅 Host 機器（執行 Vagrant 的這台電腦）能直接連線。  
> 以下整理兩種存取場景。

### 場景 A：從 Host 機器存取（最簡單）

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

### 場景 B：從另一台電腦（同 LAN 或遠端）存取

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

> API Server 憑證**未包含** Host 的 LAN IP；務必設 `tls-server-name: 192.168.56.10`，否則需加 `insecure-skip-tls-verify: true`（僅測試環境使用）。

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

## RBAC 設定實戰

> **RBAC（Role-Based Access Control）** 是 CKA 的高頻考點！  
> 核心概念：**Who（SA/User）** 透過 **RoleBinding/ClusterRoleBinding** 取得 **Role/ClusterRole** 所定義的 **What（API 操作權限）**

### RBAC 核心資源關係圖

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

### Namespace 建立

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

### ServiceAccount 建立

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

### Role 定義（Namespace 範圍）

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

### RoleBinding（將 Role 綁給 ServiceAccount）

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

### ClusterRole（跨 Namespace 範圍）

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

### ClusterRoleBinding

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

### 套用所有 RBAC 設定

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

### RBAC 驗證指令（CKA 高頻指令）

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

## CKA 重點考點整理

### 叢集架構與安裝（25%）

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

### 工作負載管理（15%）

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

### 排程（Scheduling）（15%）

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

### 儲存（Storage）（10%）

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

### 網路（Networking）（20%）

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

### 故障排查（Troubleshooting）（30%）

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

### CKA 考試必備技巧

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

## 常見問題排查

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

## 叢集生命週期管理

依需求選擇下列操作：

| 情境 | 指令 | RAM 釋放 | 復原速度 | 資料保留 |
|------|------|---------|---------|---------|
| **臨時離開**（午餐、會議） | `vagrant suspend` | 不釋放 | ~10-20 秒 | 連 in-memory 狀態 |
| **長時間關閉**（過夜、隔日繼續） | `vagrant halt` | 釋放 | ~30-60 秒 | 磁碟資料保留，叢集自動 reconcile |
| **完全銷毀**（重新練習） | `vagrant destroy -f` | 釋放 | 10+ 分鐘（重建） | 全清空 |
| **保留 VM 重置 K8s** | `kubeadm reset` | — | — | VM 保留，K8s 狀態清空 |

> `vagrant halt` 不是 pause，而是 **優雅關機**；真正的暫停是 `vagrant suspend`（VM 狀態 snapshot 到磁碟，RAM 仍占空間但 CPU 釋放）。

### 暫停與復原（推薦日常使用）

本專案附帶 helper 腳本，依正確順序操作 3 台 VM：

```bash
# 暫停整個叢集（在 Host 機器、Vagrantfile 同目錄執行）
./scripts/pause-cluster.sh

# 復原（master 先起，等 API Server Ready 後再起 workers）
./scripts/resume-cluster.sh
```

或手動執行（不需腳本時）：

```bash
# 暫停（順序不重要）
vagrant suspend k8s-node2 k8s-node1 k8s-master

# 復原（建議 master 先，避免 workers 連不到 API Server）
vagrant resume k8s-master
vagrant resume k8s-node1 k8s-node2
```

### 關機與開機

```bash
vagrant halt              # 優雅關機，全部 VM 進入 poweroff 狀態
vagrant up                # 開機（已 provisioned 過，跳過 setup 腳本）
```

### 完全銷毀

```bash
vagrant destroy -f        # 刪除全部 VM 與磁碟，需重新 vagrant up 建立
```

### 保留 VM 但只重置 K8s

不刪 VM，只把 K8s 狀態清光，便於重練 `kubeadm init` 流程：

```bash
vagrant ssh k8s-master
  sudo kubeadm reset -f
  sudo rm -rf /etc/kubernetes /var/lib/etcd $HOME/.kube
  exit

vagrant ssh k8s-node1
  sudo kubeadm reset -f
  exit

vagrant ssh k8s-node2
  sudo kubeadm reset -f
  exit

# 重新跑 master + worker provision
vagrant provision k8s-master
vagrant provision k8s-node1 k8s-node2
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

# Lab 練習篇

---

# Domain 1：叢集架構、安裝與設定

---

## Lab 01 etcd 備份與還原

> 🟡 Medium｜考域 25%｜預估時間：15 分鐘  
> **考試頻率：極高** — 幾乎每次必考

### 背景知識

etcd 是 K8s 唯一的持久化儲存，所有叢集狀態（Pod、Deployment、Secret 等）都存在這裡。  
**備份 etcd = 備份整個叢集狀態**。

```
etcd 資料流：
kubectl apply → API Server → etcd 寫入
                            ↓
                     /var/lib/etcd/
```

### 練習題

**題目 1**：將 etcd 備份到 `/opt/backup/etcd-snapshot.db`

**題目 2**：驗證備份檔案是否有效

**題目 3**：從備份還原 etcd（模擬資料遺失場景）

### 解題步驟

```bash
# ── Step 1：安裝 etcdctl ──────────────────────────────────
# etcdctl 通常已在 Master 節點安裝
etcdctl version

# 若未安裝：
ETCD_VER=v3.5.10
curl -fsSL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" \
  | tar xz -C /usr/local/bin --strip-components=1 etcd-${ETCD_VER}-linux-amd64/etcdctl

# ── Step 2：找出 etcd 憑證位置 ───────────────────────────
# 從 etcd Pod manifest 查看
cat /etc/kubernetes/manifests/etcd.yaml | grep -E "cert|key|ca"

# 通常在：
# CA:   /etc/kubernetes/pki/etcd/ca.crt
# CERT: /etc/kubernetes/pki/etcd/server.crt
# KEY:  /etc/kubernetes/pki/etcd/server.key

# ── Step 3：備份 ─────────────────────────────────────────
mkdir -p /opt/backup

ETCDCTL_API=3 etcdctl snapshot save /opt/backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 預期輸出：
# Snapshot saved at /opt/backup/etcd-snapshot.db

# ── Step 4：驗證備份 ──────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot status /opt/backup/etcd-snapshot.db \
  --write-out=table

# 預期輸出（範例）：
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | a1b2c3d4 |     1234 |        512 |    2.5 MB  |
# +----------+----------+------------+------------+

# ── Step 5：還原 etcd（模擬災難還原）───────────────────────
# 重要：還原前先停止 API Server（避免衝突）
# Static Pod 方式：暫時移走 manifest
mv /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.bak

# 等 etcd Pod 消失
sleep 10
crictl ps | grep etcd   # 應為空

# 還原到新目錄
ETCDCTL_API=3 etcdctl snapshot restore /opt/backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=k8s-master=https://192.168.56.10:2380 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://192.168.56.10:2380

# 修改 etcd manifest 指向新 data-dir
sed -i 's|/var/lib/etcd|/var/lib/etcd-restore|g' /tmp/etcd.yaml.bak

# 放回 manifest（kubelet 自動重啟 etcd）
mv /tmp/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml

# 等待 etcd 恢復
sleep 20
kubectl get nodes   # 應正常顯示
```

### 驗證

```bash
# 備份前建立資源，還原後確認是否存在
kubectl create namespace etcd-test
kubectl run test-pod --image=nginx -n etcd-test
# 執行備份... 刪除 namespace... 還原後：
kubectl get namespace etcd-test   # 應該回來
```

---

## Lab 02 叢集版本升級

> 🔴 Hard｜考域 25%｜預估時間：20 分鐘  
> **重要提示**：必須按順序：Control Plane → Worker Nodes

### 升級路徑規則

```
K8s 只允許小版本升級（1.29 → 1.30，不可跳版）

升級順序：
1. kubeadm（在 Control Plane）
2. Control Plane 元件（kubeadm upgrade apply）
3. kubelet + kubectl（Control Plane）
4. 每個 Worker Node（drain → upgrade → uncordon）
```

### 練習題

**題目**：將叢集從 1.29.x 升級到 1.30.x

### 解題步驟

```bash
# ════════════════════════════════════════════
# PHASE 1：升級 Control Plane（k8s-master）
# ════════════════════════════════════════════
vagrant ssh k8s-master

# Step 1：解鎖 kubeadm
sudo apt-mark unhold kubeadm

# Step 2：升級 kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.0-1.1
sudo apt-mark hold kubeadm

# 驗證版本
kubeadm version

# Step 3：查看升級計畫
sudo kubeadm upgrade plan

# Step 4：執行升級（只升 Control Plane 元件）
sudo kubeadm upgrade apply v1.30.0

# 預期輸出最後：
# [upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.30.0"

# Step 5：升級 kubelet 與 kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
sudo apt-mark hold kubelet kubectl

# Step 6：重啟 kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Step 7：確認 Master 升級完成
kubectl get nodes
# k8s-master 應顯示 v1.30.0

# ════════════════════════════════════════════
# PHASE 2：升級 Worker Node 1（在 master 操作）
# ════════════════════════════════════════════

# Step 1：排空節點（驅逐 Pod）
kubectl drain k8s-node1 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# 確認節點狀態變為 SchedulingDisabled
kubectl get nodes

# Step 2：SSH 進入 Worker Node 執行升級
vagrant ssh k8s-node1

sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y \
  kubeadm=1.30.0-1.1 \
  kubelet=1.30.0-1.1 \
  kubectl=1.30.0-1.1
sudo apt-mark hold kubeadm kubelet kubectl

# 升級節點設定
sudo kubeadm upgrade node

# 重啟 kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

exit   # 離開 node1

# Step 3：恢復節點排程
kubectl uncordon k8s-node1

# ════════════════════════════════════════════
# PHASE 3：重複 PHASE 2 步驟升級 k8s-node2
# ════════════════════════════════════════════
kubectl drain k8s-node2 --ignore-daemonsets --delete-emptydir-data --force
# ... (同上步驟) ...
kubectl uncordon k8s-node2

# ── 最終驗證 ──────────────────────────────────────────────
kubectl get nodes
# NAME         STATUS   VERSION
# k8s-master   Ready    v1.30.0
# k8s-node1    Ready    v1.30.0
# k8s-node2    Ready    v1.30.0
```

---

## Lab 03 節點維護：Drain & Uncordon

> 🟢 Easy｜考域 25%｜預估時間：8 分鐘

### 背景知識

```
cordon   → 封鎖節點（新 Pod 不排進去，現有 Pod 不動）
drain    → 排空節點（封鎖 + 驅逐現有 Pod）
uncordon → 解除封鎖（恢復正常排程）
```

### 練習題

**題目 1**：封鎖 k8s-node2，確認新 Pod 不會排到該節點

**題目 2**：將 k8s-node1 排空以進行維護

**題目 3**：維護完成後恢復 k8s-node1

### 解題步驟

```bash
# ── 題目 1：cordon ────────────────────────────────────────
kubectl cordon k8s-node2

# 確認狀態
kubectl get nodes
# k8s-node2  Ready,SchedulingDisabled

# 建立 Deployment 觀察排程
kubectl create deployment cordon-test --image=nginx --replicas=4
kubectl get pods -o wide   # 所有 Pod 應在 node1（node2 被封鎖）

# 清理
kubectl delete deployment cordon-test
kubectl uncordon k8s-node2

# ── 題目 2：drain（含常見旗標說明）──────────────────────────
# 先建立測試 Pod
kubectl run drain-test --image=nginx
kubectl get pods -o wide   # 記錄在哪個節點

# 排空 k8s-node1
kubectl drain k8s-node1 \
  --ignore-daemonsets \     # 忽略 DaemonSet Pod（必加，否則報錯）
  --delete-emptydir-data \  # 允許刪除使用 emptyDir 的 Pod
  --force                   # 強制刪除 naked Pod（無 controller 管理的 Pod）

# 確認 node1 已無一般 Pod（DaemonSet 除外）
kubectl get pods -o wide -A | grep node1

# ── 題目 3：uncordon 恢復 ────────────────────────────────
kubectl uncordon k8s-node1
kubectl get nodes
# k8s-node1 應回到 Ready 狀態
```

---

## Lab 04 kubeconfig 管理與多叢集切換

> 🟡 Medium｜考域 25%｜預估時間：10 分鐘

### 練習題

**題目 1**：查看並理解 kubeconfig 結構

**題目 2**：建立新的 context 並切換

**題目 3**：為特定 ServiceAccount 產生 kubeconfig

### 解題步驟

```bash
# ── 題目 1：kubeconfig 結構 ───────────────────────────────
kubectl config view          # 查看完整設定
kubectl config view --minify # 只顯示當前 context

# kubeconfig 三大元素：
# clusters  → 叢集（API Server 位址 + CA 憑證）
# users     → 使用者（憑證或 token）
# contexts  → 將 cluster + user + namespace 組合命名

# ── 題目 2：建立 context ──────────────────────────────────
# 建立指向 dev namespace 的 context
kubectl config set-context dev-context \
  --cluster=kubernetes \
  --namespace=dev \
  --user=kubernetes-admin

# 查看所有 context
kubectl config get-contexts

# 切換 context
kubectl config use-context dev-context

# 驗證：現在 kubectl get pods 預設在 dev namespace
kubectl get pods   # 等同 kubectl get pods -n dev

# 切回預設
kubectl config use-context kubernetes-admin@kubernetes

# ── 題目 3：為 ServiceAccount 產生 kubeconfig ─────────────
# 建立 SA
kubectl create serviceaccount ci-robot -n dev

# K8s 1.24+ 需手動建立 Secret（舊版自動建立）
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ci-robot-token
  namespace: dev
  annotations:
    kubernetes.io/service-account.name: ci-robot
type: kubernetes.io/service-account-token
EOF

# 取得 token
TOKEN=$(kubectl get secret ci-robot-token -n dev \
  -o jsonpath='{.data.token}' | base64 -d)

# 取得 CA 憑證
CA=$(kubectl get secret ci-robot-token -n dev \
  -o jsonpath='{.data.ca\.crt}')

# 產生 kubeconfig 檔案
cat > /tmp/ci-robot-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA}
    server: https://192.168.56.10:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: dev
    user: ci-robot
  name: ci-robot@kubernetes
current-context: ci-robot@kubernetes
users:
- name: ci-robot
  user:
    token: ${TOKEN}
EOF

# 測試新 kubeconfig
kubectl --kubeconfig=/tmp/ci-robot-kubeconfig.yaml get pods -n dev
```

---

## Lab 05 RBAC 綜合練習

> 🟡 Medium｜考域 25%｜預估時間：15 分鐘  
> **考試頻率：高** — 多場景組合考

### 練習題

**題目 1**：建立 `app-developer` ServiceAccount，允許在 `staging` namespace 管理 Pod 和 Deployment

**題目 2**：建立 `log-viewer` ClusterRole，只允許讀取所有 namespace 的 Pod logs

**題目 3**：驗證 `app-developer` 不能存取 `prod` namespace

**題目 4**：使用 imperative 指令（不寫 YAML）完成以下需求：
- User `john` 能在 `default` namespace 讀取 ConfigMap

### 解題步驟

```bash
# ── 題目 1：app-developer 設定 ───────────────────────────
kubectl create namespace staging

# 建立 SA（imperative 方式，考試必用）
kubectl create serviceaccount app-developer -n staging

# 建立 Role（一行指令）
kubectl create role app-dev-role \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=pods,deployments,replicasets \
  --namespace=staging

# 建立 RoleBinding
kubectl create rolebinding app-dev-binding \
  --role=app-dev-role \
  --serviceaccount=staging:app-developer \
  --namespace=staging

# ── 題目 2：log-viewer ClusterRole ───────────────────────
kubectl create clusterrole log-viewer \
  --verb=get \
  --resource=pods/log

# 建立 SA 並綁定
kubectl create serviceaccount log-viewer-sa -n kube-system
kubectl create clusterrolebinding log-viewer-binding \
  --clusterrole=log-viewer \
  --serviceaccount=kube-system:log-viewer-sa

# ── 題目 3：驗證跨 namespace 隔離 ────────────────────────
kubectl create namespace prod

# app-developer 能在 staging 操作嗎？
kubectl auth can-i list pods \
  --namespace=staging \
  --as=system:serviceaccount:staging:app-developer
# 預期：yes

# app-developer 能在 prod 操作嗎？
kubectl auth can-i list pods \
  --namespace=prod \
  --as=system:serviceaccount:staging:app-developer
# 預期：no

# log-viewer 能讀取任意 namespace 的 logs 嗎？
kubectl auth can-i get pods/log \
  --namespace=prod \
  --as=system:serviceaccount:kube-system:log-viewer-sa
# 預期：yes

# ── 題目 4：User john 的 ConfigMap 讀取權 ────────────────
kubectl create role cm-reader \
  --verb=get,list,watch \
  --resource=configmaps \
  --namespace=default

kubectl create rolebinding john-cm-reader \
  --role=cm-reader \
  --user=john \
  --namespace=default

# 驗證
kubectl auth can-i list configmaps \
  --namespace=default \
  --as=john
# 預期：yes
```

---

# Domain 2：工作負載與排程

---

## Lab 06 Deployment 全操作

> 🟢 Easy｜考域 15%｜預估時間：12 分鐘

### 練習題

**題目 1**：建立 nginx Deployment，3 個 replica，設定 resource limits

**題目 2**：執行滾動更新（1.25 → 1.26），觀察過程

**題目 3**：更新後發現問題，執行回滾到上一版

**題目 4**：設定 HPA，CPU 使用率超過 50% 時自動擴展（最多 8 個 replica）

### 解題步驟

```bash
# ── 題目 1：建立 Deployment ───────────────────────────────
kubectl create deployment web-app \
  --image=nginx:1.25-alpine \
  --replicas=3 \
  --dry-run=client -o yaml > /tmp/web-app-deploy.yaml

# 編輯加入 resource limits
cat > /tmp/web-app-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 更新時最多超出 1 個
      maxUnavailable: 0  # 更新時最多不可用 0 個（確保零停機）
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:   # 就緒探針：Pod 準備好才接收流量
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:    # 存活探針：失敗則重啟 container
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
EOF

kubectl apply -f /tmp/web-app-deploy.yaml
kubectl rollout status deployment/web-app

# ── 題目 2：滾動更新 ──────────────────────────────────────
# 更新 image 版本
kubectl set image deployment/web-app nginx=nginx:1.26-alpine

# 即時觀察更新過程
kubectl rollout status deployment/web-app --watch

# 查看更新歷史
kubectl rollout history deployment/web-app

# 查看特定版本詳細資訊
kubectl rollout history deployment/web-app --revision=2

# ── 題目 3：回滾 ──────────────────────────────────────────
# 回滾到上一版
kubectl rollout undo deployment/web-app

# 或回滾到特定版本
kubectl rollout undo deployment/web-app --to-revision=1

# 確認版本
kubectl get deployment web-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# ── 題目 4：HPA ───────────────────────────────────────────
# 先安裝 metrics-server（HPA 依賴）
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Calico 環境需加 --kubelet-insecure-tls
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 建立 HPA
kubectl autoscale deployment web-app \
  --min=3 \
  --max=8 \
  --cpu-percent=50

# 查看 HPA 狀態
kubectl get hpa

# 壓力測試（觸發 HPA 擴展）
kubectl run load-test --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://$(kubectl get svc web-app -o jsonpath='{.spec.clusterIP}'); done"

# 觀察 HPA 反應
kubectl get hpa -w
```

---

## Lab 07 排程控制：Taint、Toleration、Affinity

> 🟡 Medium｜考域 15%｜預估時間：15 分鐘

### 練習題

**題目 1**：將 k8s-node2 標記為 `gpu=true`，只讓有 GPU 需求的 Pod 排到這台

**題目 2**：建立 Pod Anti-Affinity，讓同一個 Deployment 的 Pod 分散在不同節點

**題目 3**：使用 nodeSelector 固定 Pod 到特定節點

### 解題步驟

```bash
# ── 題目 1：Taint & Toleration ────────────────────────────
# 為 node2 加 Taint（汙點）
kubectl taint nodes k8s-node2 gpu=true:NoSchedule

# 建立不帶 Toleration 的 Pod（不會排到 node2）
kubectl run no-gpu --image=nginx
kubectl get pod no-gpu -o wide  # 只在 node1

# 建立帶 Toleration 的 Pod（可以排到 node2）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  tolerations:
  - key: "gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  nodeSelector:
    kubernetes.io/hostname: k8s-node2   # 配合 nodeSelector 強制排到 node2
  containers:
  - name: cuda-app
    image: nginx
EOF

kubectl get pod gpu-pod -o wide  # 應在 node2

# 清理 Taint
kubectl taint nodes k8s-node2 gpu=true:NoSchedule-   # 加 - 移除

# ── 題目 2：Pod Anti-Affinity 分散部署 ───────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      affinity:
        podAntiAffinity:
          # requiredDuring = 硬性要求（找不到符合節點則 Pending）
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: ["spread-app"]
            topologyKey: kubernetes.io/hostname   # 以節點為單位分散
      containers:
      - name: app
        image: nginx:alpine
EOF

kubectl get pods -l app=spread-app -o wide
# 4 個 Pod 應分散在 node1 和 node2

# ── 題目 3：nodeSelector ──────────────────────────────────
# 為節點加 Label
kubectl label nodes k8s-node1 disk=ssd

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ssd-pod
spec:
  nodeSelector:
    disk: ssd      # 只排到有 disk=ssd 標籤的節點
  containers:
  - name: app
    image: nginx
EOF

kubectl get pod ssd-pod -o wide  # 應在 node1
```

---

## Lab 08 DaemonSet 與 StaticPod

> 🟡 Medium｜考域 15%｜預估時間：12 分鐘

### DaemonSet 說明

```
DaemonSet 確保每個節點（或符合條件的節點）都跑一個 Pod 副本
用途：日誌收集、節點監控、網路代理（Calico 本身就是 DaemonSet）
```

### 練習題

**題目 1**：建立 DaemonSet 在所有 Worker Node 部署 log-agent

**題目 2**：建立 StaticPod（在 k8s-node1 上，不透過 API Server）

### 解題步驟

```bash
# ── 題目 1：DaemonSet ─────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
  namespace: default
spec:
  selector:
    matchLabels:
      app: log-agent
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      # 讓 DaemonSet 也能排到 Master（預設 Master 有 Taint）
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: log-agent
        image: busybox
        command: ["sh", "-c", "while true; do echo 'collecting logs...'; sleep 30; done"]
        resources:
          limits:
            memory: "50Mi"
            cpu: "50m"
EOF

kubectl get daemonset log-agent
kubectl get pods -l app=log-agent -o wide
# 應在每個節點各跑一個 Pod

# ── 題目 2：StaticPod ─────────────────────────────────────
# StaticPod 由 kubelet 直接管理，API Server 不能刪除它
# 設定檔放在 /etc/kubernetes/manifests/（各節點）

vagrant ssh k8s-node1

# 查看 staticPodPath（應為 /etc/kubernetes/manifests）
sudo grep -i staticPodPath /var/lib/kubelet/config.yaml

# 建立 StaticPod manifest
sudo cat > /etc/kubernetes/manifests/static-nginx.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

# kubelet 自動偵測並啟動（約 10 秒）
# 在 master 上可以看到，但無法用 kubectl delete 刪除
kubectl get pod static-nginx-k8s-node1

# 要刪除 StaticPod：刪除各節點上的 manifest 檔案
sudo rm /etc/kubernetes/manifests/static-nginx.yaml
```

---

## Lab 09 ConfigMap 與 Secret

> 🟢 Easy｜考域 15%｜預估時間：10 分鐘

### 練習題

**題目 1**：從字面值建立 ConfigMap，掛載為環境變數

**題目 2**：從檔案建立 ConfigMap，掛載為 Volume

**題目 3**：建立 Secret 儲存資料庫密碼，注入 Pod

### 解題步驟

```bash
# ── 題目 1：ConfigMap → 環境變數 ──────────────────────────
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080 \
  --from-literal=LOG_LEVEL=info

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env | grep APP && sleep 3600"]
    env:
    - name: APP_ENV             # 單一 key 注入
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    envFrom:                    # 整個 ConfigMap 注入
    - configMapRef:
        name: app-config
EOF

kubectl logs env-pod   # 確認環境變數

# ── 題目 2：ConfigMap → Volume ────────────────────────────
# 建立設定檔 ConfigMap
kubectl create configmap nginx-conf \
  --from-literal=nginx.conf="server { listen 80; location / { return 200 'OK'; } }"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-pod
spec:
  volumes:
  - name: config-vol
    configMap:
      name: nginx-conf
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "cat /etc/config/nginx.conf && sleep 3600"]
    volumeMounts:
    - name: config-vol
      mountPath: /etc/config   # ConfigMap 的每個 key 成為一個檔案
EOF

kubectl exec volume-pod -- cat /etc/config/nginx.conf

# ── 題目 3：Secret ────────────────────────────────────────
# Secret 的 value 是 base64 編碼（不是加密！）
kubectl create secret generic db-secret \
  --from-literal=DB_PASSWORD=P@ssw0rd123 \
  --from-literal=DB_HOST=mysql.prod.svc.cluster.local

# 查看 Secret（base64 解碼）
kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo $DB_PASSWORD && sleep 3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: DB_PASSWORD
EOF

kubectl exec secret-pod -- env | grep DB_PASSWORD
```

---

## Lab 10 多容器 Pod：Init、Sidecar

> 🟡 Medium｜考域 15%｜預估時間：12 分鐘

### 練習題

**題目 1**：建立 Init Container，在主容器啟動前準備設定檔

**題目 2**：建立 Sidecar（邊車）容器，共享 Volume 收集日誌

### 解題步驟

```bash
# ── 題目 1：Init Container ────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: init-pod
spec:
  initContainers:
  - name: init-config           # Init Container 先執行
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Preparing config..." &&
      echo "server: production" > /config/app.yaml &&
      echo "Init done!"
    volumeMounts:
    - name: config-vol
      mountPath: /config

  containers:
  - name: main-app              # Init 完成後才啟動
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Reading config:" &&
      cat /config/app.yaml &&
      sleep 3600
    volumeMounts:
    - name: config-vol
      mountPath: /config

  volumes:
  - name: config-vol
    emptyDir: {}
EOF

# 觀察啟動順序
kubectl get pod init-pod -w
# Init:0/1 → PodInitializing → Running

kubectl logs init-pod -c init-config
kubectl logs init-pod -c main-app

# ── 題目 2：Sidecar 日誌收集 ─────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-pod
spec:
  containers:
  - name: web-server           # 主應用：寫日誌到共享 Volume
    image: nginx:alpine
    volumeMounts:
    - name: log-vol
      mountPath: /var/log/nginx

  - name: log-collector        # Sidecar：讀取並轉發日誌
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Log collector started"
      tail -f /logs/access.log 2>/dev/null || \
      while true; do
        echo "[$(date)] No logs yet, waiting..." 
        sleep 10
      done
    volumeMounts:
    - name: log-vol
      mountPath: /logs          # 掛到同一個 Volume

  volumes:
  - name: log-vol
    emptyDir: {}
EOF

# 查看 Sidecar 日誌
kubectl logs sidecar-pod -c log-collector
```

---

## Lab 11 Job 與 CronJob

> 🟡 Medium｜考域 15%｜預估時間：10 分鐘

### 練習題

**題目 1**：建立 Job 執行一次性任務，確認完成後保留 logs

**題目 2**：建立 CronJob 每分鐘執行一次，限制保留 3 個歷史 Job

### 解題步驟

```bash
# ── 題目 1：Job ───────────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-process
spec:
  completions: 3              # 需要成功完成 3 次
  parallelism: 2              # 最多同時跑 2 個 Pod
  backoffLimit: 2             # 失敗重試上限
  ttlSecondsAfterFinished: 300  # 完成後 5 分鐘自動清理
  template:
    spec:
      restartPolicy: OnFailure   # Job 必須設定（不能用 Always）
      containers:
      - name: processor
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Processing batch job $(hostname)"
          sleep 5
          echo "Done!"
EOF

# 觀察 Job 執行
kubectl get job data-process -w
kubectl get pods -l job-name=data-process

# 查看日誌
kubectl logs -l job-name=data-process --tail=5

# ── 題目 2：CronJob ───────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-check
spec:
  schedule: "*/1 * * * *"    # 每分鐘執行（cron 語法）
  successfulJobsHistoryLimit: 3   # 保留 3 個成功 Job
  failedJobsHistoryLimit: 1       # 保留 1 個失敗 Job
  concurrencyPolicy: Forbid       # 禁止並行（前一個未完成就跳過）
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: health-check
            image: busybox
            command: ["sh", "-c", "echo 'Health check at $(date)'"]
EOF

# 等待 1 分鐘後觀察
kubectl get cronjob health-check
kubectl get jobs | grep health-check

# 手動觸發 CronJob（測試用）
kubectl create job manual-run --from=cronjob/health-check
```

---

# Domain 3：服務與網路

---

## Lab 12 Service 四種類型實作

> 🟢 Easy｜考域 20%｜預估時間：12 分鐘

### Service 類型對比

```
ClusterIP   → 叢集內部存取（預設），有固定 IP
NodePort    → 透過節點 IP + Port 對外（30000-32767）
LoadBalancer→ 雲端環境，取得外部 IP（本環境不適用）
ExternalName→ 將 Service 對應到外部 DNS 名稱
```

### 練習題

**題目**：為 nginx Deployment 分別建立各種 Service 並驗證連通性

### 解題步驟

```bash
# 先建立 Deployment
kubectl create deployment svc-test --image=nginx --replicas=2
kubectl expose deployment svc-test --port=80 --name=clusterip-svc
# 預設為 ClusterIP

# ── ClusterIP ─────────────────────────────────────────────
CLUSTER_IP=$(kubectl get svc clusterip-svc -o jsonpath='{.spec.clusterIP}')
# 在叢集內測試（從任意 Pod 存取）
kubectl run curl-test --image=curlimages/curl --restart=Never -- \
  curl -s http://${CLUSTER_IP}
kubectl logs curl-test
kubectl delete pod curl-test

# ── NodePort ──────────────────────────────────────────────
kubectl expose deployment svc-test \
  --port=80 \
  --type=NodePort \
  --name=nodeport-svc

# 查看分配的 NodePort
kubectl get svc nodeport-svc
# 從 Host 機器測試（透過 VirtualBox Host-Only 網路）
# curl http://192.168.56.11:<NodePort>

# ── ExternalName（將 K8s Service 對應外部服務）────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: default
spec:
  type: ExternalName
  externalName: mysql.example.com   # 外部 DNS 名稱
EOF

# 叢集內部 Pod 可用 external-db 這個名稱存取外部 MySQL
kubectl get svc external-db

# ── 端點（Endpoints）查看 ─────────────────────────────────
kubectl get endpoints clusterip-svc
kubectl describe service clusterip-svc
```

---

## Lab 13 NetworkPolicy 流量管控

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

### 練習題

**題目 1**：在 `secure` namespace 設定「預設拒絕所有流量」

**題目 2**：只允許 `frontend` Pod 存取 `backend` Pod 的 8080 port

**題目 3**：允許 `kube-system` namespace 的 CoreDNS 查詢（避免 DNS 壞掉）

### 解題步驟

```bash
# 建立環境
kubectl create namespace secure
kubectl run frontend --image=nginx -n secure --labels="role=frontend"
kubectl run backend --image=nginx -n secure --labels="role=backend"

# ── 題目 1：預設拒絕 ─────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: secure
spec:
  podSelector: {}    # 選取所有 Pod
  policyTypes:
  - Ingress
  - Egress           # 同時封鎖入站和出站
EOF

# 測試：frontend 應無法存取 backend
BACKEND_IP=$(kubectl get pod backend -n secure -o jsonpath='{.status.podIP}')
kubectl exec -n secure frontend -- curl -s --connect-timeout 3 http://${BACKEND_IP}
# 預期：connection timed out

# ── 題目 2：允許特定 Pod 間通訊 ──────────────────────────
cat <<'EOF' | kubectl apply -f -
# 允許 backend 接收來自 frontend 的流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: secure
spec:
  podSelector:
    matchLabels:
      role: backend       # 此 policy 保護 backend Pod
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend  # 只允許 frontend Pod 進入
    ports:
    - protocol: TCP
      port: 80            # 只開放 80 port

---
# 同時要允許 frontend 發出 egress 到 backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress
  namespace: secure
spec:
  podSelector:
    matchLabels:
      role: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: backend
    ports:
    - protocol: TCP
      port: 80
  - to:                   # 允許 DNS 查詢（重要！）
    ports:
    - protocol: UDP
      port: 53
EOF

# 測試：frontend 現在可以存取 backend
kubectl exec -n secure frontend -- curl -s --connect-timeout 5 http://${BACKEND_IP}
# 預期：nginx 歡迎頁面
```

---

## Lab 14 Ingress 設定

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

### 練習題

**題目**：安裝 Nginx Ingress Controller，設定路徑路由（/app1 → service1, /app2 → service2）

### 解題步驟

```bash
# ── 安裝 Nginx Ingress Controller ────────────────────────
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

# 等待就緒
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# ── 建立後端服務 ──────────────────────────────────────────
kubectl create deployment app1 --image=hashicorp/http-echo -- \
  --text="Hello from App1"
kubectl expose deployment app1 --port=5678

kubectl create deployment app2 --image=hashicorp/http-echo -- \
  --text="Hello from App2"
kubectl expose deployment app2 --port=5678

# ── 設定 Ingress 路由 ─────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /   # 重寫路徑
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local           # 對應到這個 hostname
    http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 5678
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 5678
EOF

# 取得 Ingress Controller 的 NodePort
kubectl get svc -n ingress-nginx
# 找到 80 對應的 NodePort（例如 30080）

# 測試（加 Host header 因為沒有真正的 DNS）
NODE_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

curl -H "Host: myapp.local" http://192.168.56.11:${NODE_PORT}/app1
# 預期：Hello from App1

curl -H "Host: myapp.local" http://192.168.56.11:${NODE_PORT}/app2
# 預期：Hello from App2
```

---

## Lab 15 DNS 與 CoreDNS 排查

> 🟢 Easy｜考域 20%｜預估時間：10 分鐘

### 練習題

**題目 1**：驗證叢集內 DNS 解析（Service 名稱 → ClusterIP）

**題目 2**：查看並修改 CoreDNS 設定

### 解題步驟

```bash
# ── 題目 1：DNS 解析驗證 ──────────────────────────────────
# K8s DNS 格式：<service>.<namespace>.svc.cluster.local

kubectl run dns-test --image=busybox --restart=Never -- \
  sh -c "nslookup kubernetes.default.svc.cluster.local && \
         nslookup clusterip-svc.default.svc.cluster.local"

kubectl logs dns-test
# 預期輸出包含正確的 IP 解析

# 短名稱（同 namespace 內可直接用 service 名稱）
kubectl run dns-short --image=busybox --restart=Never -- \
  sh -c "nslookup clusterip-svc"
kubectl logs dns-short

# ── 題目 2：CoreDNS 設定 ──────────────────────────────────
# 查看 CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# CoreDNS Corefile 說明：
# cluster.local  → 叢集內部域名
# forward        → 上游 DNS（無法解析時轉發到 /etc/resolv.conf）
# cache          → DNS 快取時間（秒）
# health         → 健康檢查 endpoint

# 新增自訂域名解析（例如：mycompany.internal）
kubectl edit configmap coredns -n kube-system
# 在 Corefile 中新增：
# mycompany.internal {
#     hosts {
#         10.0.0.100 internal.mycompany.internal
#         fallthrough
#     }
# }

# 重啟 CoreDNS 套用設定
kubectl rollout restart deployment coredns -n kube-system
```

---

# Domain 4：儲存

---

## Lab 16 PV / PVC / StorageClass

> 🟡 Medium｜考域 10%｜預估時間：15 分鐘

### 練習題

**題目 1**：手動建立 PV 和 PVC，掛到 Pod 中

**題目 2**：了解 PV 的 Reclaim Policy 差異

**題目 3**：查看 StorageClass，使用動態佈建

### 解題步驟

```bash
# ── 題目 1：靜態佈建 PV + PVC ────────────────────────────
# 先在每個節點建立目錄
vagrant ssh k8s-node1
sudo mkdir -p /data/pv-001
sudo chmod 777 /data/pv-001
exit

cat <<'EOF' | kubectl apply -f -
# PV：叢集管理員建立（代表實際儲存資源）
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath-001
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce       # 只能被單一節點掛載為讀寫
  persistentVolumeReclaimPolicy: Retain  # PVC 刪除後保留資料
  storageClassName: ""    # 空字串 = 不用 StorageClass（靜態綁定）
  hostPath:
    path: /data/pv-001    # 測試用；生產應使用 NFS/Ceph 等
    type: DirectoryOrCreate
---
# PVC：開發者申請儲存空間
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-app-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi      # 申請 500Mi（PV 有 1Gi，可以綁定）
  storageClassName: ""    # 對應空 StorageClass 的 PV
EOF

# 確認綁定成功
kubectl get pv,pvc
# PV 和 PVC 狀態應為 Bound

# 掛載到 Pod
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: pvc-app-data   # 引用 PVC
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo 'data saved' > /data/file.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
EOF

kubectl exec pvc-pod -- cat /data/file.txt
# 資料持久化：Pod 重啟後仍存在

# ── 題目 2：Reclaim Policy 說明 ───────────────────────────
# Retain  → PVC 刪除後，PV 狀態變 Released，資料保留，需手動清理
# Delete  → PVC 刪除後，PV 和底層儲存一起刪除（動態佈建預設）
# Recycle → 已棄用，不使用

# ── 題目 3：查看 StorageClass ─────────────────────────────
kubectl get storageclass
kubectl describe storageclass <name>

# 使用 StorageClass 動態佈建（不需要手動建 PV）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # 不指定 storageClassName 則使用預設的
  # storageClassName: standard
EOF
```

---

## Lab 17 Volume 類型：emptyDir、hostPath、configMap

> 🟢 Easy｜考域 10%｜預估時間：8 分鐘

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-types-demo
spec:
  volumes:
  # 1. emptyDir：同 Pod 內容器共享，Pod 刪除後消失
  - name: shared-data
    emptyDir: {}

  # 2. hostPath：掛載節點檔案系統（有安全風險）
  - name: host-logs
    hostPath:
      path: /var/log
      type: Directory

  # 3. configMap：將設定檔掛進來
  - name: app-config
    configMap:
      name: app-config   # 引用前面 Lab 建立的 ConfigMap

  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo 'shared' > /shared/data.txt && sleep 3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /shared

  - name: reader
    image: busybox
    command: ["sh", "-c", "sleep 5 && cat /shared/data.txt && sleep 3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /shared
    - name: host-logs
      mountPath: /host-logs
      readOnly: true       # 唯讀掛載節點日誌
    - name: app-config
      mountPath: /etc/app
EOF

kubectl exec volume-types-demo -c reader -- cat /shared/data.txt
kubectl exec volume-types-demo -c reader -- ls /etc/app/
```

---

# Domain 5：故障排查（最高比重 30%）

---

## Lab 18 Pod 故障排查

> 🟡 Medium｜考域 30%｜預估時間：15 分鐘

### 練習題（刻意製造 Bug，自行找出並修復）

**題目 1**：以下 Pod 無法啟動，找出並修復問題

**題目 2**：Pod 一直 CrashLoopBackOff，找出原因

**題目 3**：Pod 停在 Pending 狀態，找出原因

### 解題步驟

```bash
# ── 題目 1：ImagePullBackOff ──────────────────────────────
# 製造問題
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod-1
spec:
  containers:
  - name: app
    image: nginx:99.99.99    # 不存在的版本
EOF

# 排查流程
kubectl get pod broken-pod-1                   # 看狀態
kubectl describe pod broken-pod-1              # 看 Events（關鍵！）
# Events 會顯示：Failed to pull image

# 修復：更新 image
kubectl set image pod/broken-pod-1 app=nginx:latest
# 或刪除重建
kubectl delete pod broken-pod-1
kubectl run broken-pod-1 --image=nginx:latest

# ── 題目 2：CrashLoopBackOff ──────────────────────────────
# 製造問題
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "exit 1"]   # 立即以錯誤碼退出
EOF

kubectl get pod crash-pod -w
# 觀察：0/1 → CrashLoopBackOff → 指數退避重試

# 排查
kubectl logs crash-pod                   # 當前日誌（可能已重啟）
kubectl logs crash-pod --previous        # 上次崩潰的日誌（重要！）
kubectl describe pod crash-pod           # 看 Exit Code 和重啟次數

# ── 題目 3：Pending 狀態 ──────────────────────────────────
# 製造問題：申請超出叢集資源的 Pod
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "100Gi"   # 遠超叢集可用資源
        cpu: "50"
EOF

kubectl get pod resource-pod     # Pending
kubectl describe pod resource-pod
# Events: 0/3 nodes are available: 3 Insufficient memory

# 排查叢集資源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 修復：降低資源需求
kubectl delete pod resource-pod
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
EOF

# ── 常用排查指令速查 ──────────────────────────────────────
kubectl get events --sort-by=.lastTimestamp -n default
kubectl get events -A | grep Warning
kubectl top pods                     # 需要 metrics-server
kubectl top nodes
```

---

## Lab 19 節點故障排查

> 🔴 Hard｜考域 30%｜預估時間：20 分鐘

### 練習題

**題目 1**：模擬 kubelet 服務停止，排查並恢復

**題目 2**：節點磁碟空間不足，找出並清理

### 解題步驟

```bash
# ── 題目 1：模擬 kubelet 故障 ────────────────────────────
# 在 k8s-node1 上停止 kubelet
vagrant ssh k8s-node1
sudo systemctl stop kubelet

exit

# 在 Master 上觀察（約 40 秒後）
kubectl get nodes
# k8s-node1 狀態變為 NotReady

kubectl describe node k8s-node1
# Conditions 中：
# KubeletReady = False
# KubeletHasSufficientMemory = Unknown

# 排查步驟
vagrant ssh k8s-node1

# 1. 檢查 kubelet 服務狀態
sudo systemctl status kubelet

# 2. 查看 kubelet 日誌
sudo journalctl -u kubelet --no-pager -n 50
sudo journalctl -u kubelet -f   # 即時追蹤

# 3. 確認設定檔
sudo cat /var/lib/kubelet/config.yaml
sudo cat /etc/kubernetes/kubelet.conf

# 4. 恢復 kubelet
sudo systemctl start kubelet
sudo systemctl enable kubelet   # 確保開機自啟

exit

# 在 Master 確認恢復
kubectl get nodes   # k8s-node1 回到 Ready

# ── 題目 2：磁碟問題排查 ──────────────────────────────────
vagrant ssh k8s-node1

# 查看磁碟使用
df -h
du -sh /var/lib/containerd/*   # containerd 映像快取通常最大

# 清理未使用的映像
sudo crictl rmi --prune

# 清理停止的容器
sudo crictl ps -a | grep Exited
sudo crictl rm $(sudo crictl ps -a -q --state exited)

exit
```

---

## Lab 20 Control Plane 元件修復

> 🔴 Hard｜考域 30%｜預估時間：20 分鐘  
> **考試頻率：高** — 刻意破壞後要求修復

### 練習題

**題目 1**：修復被破壞的 kube-apiserver 設定

**題目 2**：修復 etcd 設定錯誤

### 解題步驟

```bash
# ── 題目 1：破壞 kube-apiserver（練習用）────────────────
vagrant ssh k8s-master

# 備份原始設定
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# 製造問題：改錯 port（考試會遇到類似情況）
sudo sed -i 's/--secure-port=6443/--secure-port=6444/' \
  /etc/kubernetes/manifests/kube-apiserver.yaml

# API Server 會停止回應
kubectl get nodes   # 連線失敗

# 排查步驟：
# 1. 查看 Static Pod manifest
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml

# 2. 查看容器狀態（不能用 kubectl，改用 crictl）
sudo crictl ps -a | grep apiserver
sudo crictl logs <container-id>

# 3. 查看系統日誌
sudo journalctl -u kubelet --no-pager -n 100 | grep apiserver

# 修復：還原設定
sudo cp /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml

# 等待重啟（約 30-60 秒）
sleep 30
kubectl get nodes

# ── 題目 2：找出 Static Pod 設定問題 ─────────────────────
# 常見考題：某個 Static Pod 有 typo，找出並修復
# 設定位置：/etc/kubernetes/manifests/
# 修改後 kubelet 自動偵測並重啟（無需任何 apply 指令）

# 查看各元件 manifest
ls -la /etc/kubernetes/manifests/
sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml
sudo cat /etc/kubernetes/manifests/kube-controller-manager.yaml

# 修改後確認 Pod 狀態
sudo crictl ps | grep -E "apiserver|scheduler|controller|etcd"
```

---

## Lab 21 網路故障排查

> 🟡 Medium｜考域 30%｜預估時間：15 分鐘

### 練習題

**題目 1**：Service 無法轉發到 Pod，找出問題（selector 錯誤）

**題目 2**：Pod 間網路不通，排查 CNI

### 解題步驟

```bash
# ── 題目 1：Service Selector 錯誤 ────────────────────────
# 製造問題
kubectl create deployment wrong-svc-test --image=nginx
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-svc
spec:
  selector:
    app: wrong-label    # 故意寫錯（Deployment label 是 wrong-svc-test）
  ports:
  - port: 80
    targetPort: 80
EOF

# 測試發現無法連線
kubectl get endpoints broken-svc
# ENDPOINTS 欄位為 <none> → Service 沒有找到對應 Pod

# 排查
kubectl get pods --show-labels    # 查看 Pod 實際 labels
kubectl describe svc broken-svc   # 查看 selector

# 修復：更新 selector
kubectl patch svc broken-svc \
  -p '{"spec":{"selector":{"app":"wrong-svc-test"}}}'

kubectl get endpoints broken-svc  # 現在應顯示 Pod IP

# ── 題目 2：網路連通性測試 ───────────────────────────────
# 部署 debug Pod
kubectl run netdebug \
  --image=nicolaka/netshoot \
  --restart=Never \
  -it -- bash

# 在 debug Pod 內：
# DNS 測試
nslookup kubernetes.default
# 連通性測試
ping <pod-ip>
curl http://<service-name>:<port>
# 路由表
ip route
# iptables 規則
iptables -t nat -L KUBE-SERVICES | head -20
exit

# 查看 Calico 狀態
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl exec -n kube-system <calico-pod> -- calico-node -bird-ready
```

---

## Lab 22 Log 分析與監控

> 🟡 Medium｜考域 30%｜預估時間：10 分鐘

### 練習題

**題目 1**：查看並過濾多種日誌來源

**題目 2**：查看節點和 Pod 資源使用量

### 解題步驟

```bash
# ── 題目 1：日誌查詢技巧 ──────────────────────────────────

# Pod 日誌
kubectl logs <pod-name>                    # 當前日誌
kubectl logs <pod-name> --previous         # 上次崩潰日誌
kubectl logs <pod-name> -f                 # 即時追蹤
kubectl logs <pod-name> --since=1h         # 最近 1 小時
kubectl logs <pod-name> --tail=50          # 最後 50 行
kubectl logs <pod-name> -c <container>     # 多容器指定

# 查看多個 Pod 日誌（透過 Label selector）
kubectl logs -l app=nginx --all-containers

# 系統元件日誌（Static Pod）
kubectl logs -n kube-system kube-apiserver-k8s-master
kubectl logs -n kube-system etcd-k8s-master

# 節點層級日誌（kubelet，需在節點上）
sudo journalctl -u kubelet -n 100
sudo journalctl -u containerd -n 100

# ── 題目 2：資源監控 ──────────────────────────────────────

# 節點資源概覽（需 metrics-server）
kubectl top nodes

# Pod 資源使用
kubectl top pods -A
kubectl top pods -n kube-system --sort-by=memory

# 節點詳細資源分配
kubectl describe node k8s-node1 | grep -A 10 "Allocated resources"

# 查看 Pod resource requests/limits
kubectl get pods -o custom-columns=\
"NAME:.metadata.name,\
CPU-REQ:.spec.containers[0].resources.requests.cpu,\
MEM-REQ:.spec.containers[0].resources.requests.memory,\
CPU-LIM:.spec.containers[0].resources.limits.cpu,\
MEM-LIM:.spec.containers[0].resources.limits.memory"
```

---

# 綜合模擬考試

## Mock Exam 01

> ⏱️ 限時 45 分鐘｜請獨立完成，不要看提示

**環境**：本 PoC 叢集（k8s-master + k8s-node1 + k8s-node2）

---

**Question 1**（8 分）

建立 namespace `exam` 和以下資源：
- Deployment `exam-web`：image=nginx:1.25，replicas=3，在 namespace `exam`
- 為 `exam-web` 建立 ClusterIP Service `exam-svc`，port 80
- 確認所有 Pod 為 Running 狀態

---

**Question 2**（12 分）

建立 RBAC 設定：
- ServiceAccount `exam-deployer` 在 namespace `exam`
- Role `exam-deploy-role`：允許對 namespace `exam` 的 deployments 執行 get/list/watch/update/patch
- 將 Role 綁定給 `exam-deployer`
- 驗證：`exam-deployer` 可以 list deployments，但不能 delete pods

---

**Question 3**（10 分）

對 etcd 執行備份：
- 備份路徑：`/opt/exam/etcd-backup.db`
- 驗證備份有效（顯示 revision 和 key 數量）

---

**Question 4**（8 分）

將 k8s-node1 設定維護模式：
- 排空 k8s-node1（允許 DaemonSet，允許刪除 emptyDir 資料）
- 模擬維護（sleep 30）
- 恢復 k8s-node1 回到正常排程

---

**Question 5**（7 分）

建立 Pod `multi-container`：
- Init Container：image=busybox，建立 `/init/ready` 檔案後退出
- Main Container：image=nginx，確認 `/init/ready` 存在後啟動
- 兩個 container 共享同一個 emptyDir Volume

---

**Question 6**（5 分）

排查：以下 Pod 有問題，找出並修復：

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: exam-broken
spec:
  containers:
  - name: web
    image: nginx:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: wrong-name    # ← 這裡有問題
    emptyDir: {}
EOF
```

---

### Mock Exam 01 解答

<details>
<summary>點此展開解答（建議先獨立完成再看）</summary>

```bash
# Q1
kubectl create namespace exam
kubectl create deployment exam-web --image=nginx:1.25 --replicas=3 -n exam
kubectl expose deployment exam-web --port=80 --name=exam-svc -n exam
kubectl get pods -n exam

# Q2
kubectl create serviceaccount exam-deployer -n exam
kubectl create role exam-deploy-role \
  --verb=get,list,watch,update,patch \
  --resource=deployments \
  --namespace=exam
kubectl create rolebinding exam-deployer-binding \
  --role=exam-deploy-role \
  --serviceaccount=exam:exam-deployer \
  --namespace=exam
# 驗證
kubectl auth can-i list deployments -n exam \
  --as=system:serviceaccount:exam:exam-deployer   # yes
kubectl auth can-i delete pods -n exam \
  --as=system:serviceaccount:exam:exam-deployer   # no

# Q3
mkdir -p /opt/exam
ETCDCTL_API=3 etcdctl snapshot save /opt/exam/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
ETCDCTL_API=3 etcdctl snapshot status /opt/exam/etcd-backup.db --write-out=table

# Q4
kubectl drain k8s-node1 --ignore-daemonsets --delete-emptydir-data
sleep 30
kubectl uncordon k8s-node1

# Q5
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
spec:
  initContainers:
  - name: init
    image: busybox
    command: ["sh", "-c", "touch /init/ready && echo 'init done'"]
    volumeMounts:
    - name: shared
      mountPath: /init
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: shared
      mountPath: /init
  volumes:
  - name: shared
    emptyDir: {}
EOF

# Q6
# 問題：volumeMounts 引用 "data" 但 volumes 定義為 "wrong-name"
kubectl delete pod exam-broken
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: exam-broken
spec:
  containers:
  - name: web
    image: nginx:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data          # ← 改成與 volumeMounts 一致
    emptyDir: {}
EOF
```

</details>

---

## Mock Exam 02

> ⏱️ 限時 45 分鐘｜進階場景

---

**Question 1**（10 分）

NetworkPolicy 設定：
- 在 namespace `netpol-test` 中建立 `frontend`（label: tier=frontend）和 `backend`（label: tier=backend）兩個 Pod
- 設定 NetworkPolicy：只有 `frontend` Pod 能存取 `backend` Pod 的 80 port
- 其他所有 ingress 流量拒絕
- 驗證 frontend 可連 backend，反向不行

---

**Question 2**（10 分）

PV/PVC 設定：
- 建立 PV `data-pv`：hostPath=/data/exam，容量=2Gi，accessMode=ReadWriteOnce，ReclaimPolicy=Retain
- 建立 PVC `data-pvc`：申請 1Gi，綁定到 `data-pv`
- 建立 Pod `data-pod`，掛載 `data-pvc` 到 `/app/data`，寫入 `Hello CKA` 到 `/app/data/test.txt`

---

**Question 3**（8 分）

節點標籤與 Pod 排程：
- 為 k8s-node1 加上 label `zone=us-east`，k8s-node2 加上 `zone=us-west`
- 建立 Deployment `zoned-app`：replicas=4，使用 nodeAffinity 讓 Pod 優先排到 `us-east` zone

---

**Question 4**（7 分）

CronJob 設定：
- 建立 CronJob `backup-job`：每 5 分鐘執行，image=busybox，輸出 `Backup at $(date)`
- 設定最多保留 2 個成功 Job，0 個失敗 Job

---

**Question 5**（10 分）

故障排查：以下服務無法存取，找出所有問題並修復（可能有多個問題）：

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-web
  template:
    metadata:
      labels:
        app: broken-web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: broken-web-svc
spec:
  selector:
    app: broken     # ← 問題 1
  ports:
  - port: 8080
    targetPort: 8888  # ← 問題 2
EOF
```

---

### Mock Exam 02 解答

<details>
<summary>點此展開解答</summary>

```bash
# Q1
kubectl create namespace netpol-test
kubectl run frontend -n netpol-test --image=nginx --labels="tier=frontend"
kubectl run backend -n netpol-test --image=nginx --labels="tier=backend"

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: netpol-test
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - port: 80
EOF

# Q2
vagrant ssh k8s-node1 -c "sudo mkdir -p /data/exam && sudo chmod 777 /data/exam"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  capacity:
    storage: 2Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/exam
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
spec:
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: data-pvc
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo 'Hello CKA' > /app/data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /app/data
EOF

# Q3
kubectl label nodes k8s-node1 zone=us-east
kubectl label nodes k8s-node2 zone=us-west

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zoned-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: zoned-app
  template:
    metadata:
      labels:
        app: zoned-app
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: zone
                operator: In
                values: ["us-east"]
      containers:
      - name: app
        image: nginx:alpine
EOF

# Q4
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "*/5 * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 0
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox
            command: ["sh", "-c", "echo \"Backup at $(date)\""]
EOF

# Q5 修復兩個問題：
# 問題 1：selector 應為 app: broken-web
# 問題 2：targetPort 應為 80（nginx 監聽 80）
kubectl patch svc broken-web-svc \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/selector/app","value":"broken-web"},
    {"op":"replace","path":"/spec/ports/0/targetPort","value":80}
  ]'

# 驗證
kubectl get endpoints broken-web-svc
# 應顯示 Pod IP:80
```

</details>

---

## 快速複習索引

```
╔══════════════════════════════════════════════════════════════╗
║                    CKA 必背指令速查                           ║
╠══════════════╦═══════════════════════════════════════════════╣
║ etcd 備份    ║ etcdctl snapshot save FILE --endpoints=...    ║
║ 叢集升級     ║ kubeadm upgrade plan / apply v1.x.x           ║
║ 節點維護     ║ kubectl drain NODE --ignore-daemonsets         ║
║ 節點恢復     ║ kubectl uncordon NODE                          ║
║ RBAC 驗證    ║ kubectl auth can-i VERB RES --as=...          ║
║ 產生 YAML    ║ kubectl create ... --dry-run=client -o yaml   ║
║ 快速刪 Pod   ║ kubectl delete pod NAME --force --grace-period=0║
║ 切換 context ║ kubectl config use-context NAME               ║
║ 查看所有資源 ║ kubectl get all -A                             ║
║ 查 Endpoints ║ kubectl get endpoints SVC-NAME                ║
║ crictl 容器  ║ crictl ps / logs / pods                       ║
║ kubelet 日誌 ║ journalctl -u kubelet -f                      ║
║ Static Pod   ║ ls /etc/kubernetes/manifests/                 ║
╚══════════════╩═══════════════════════════════════════════════╝
```

---

*CKA 認證實戰練習手冊 v2.0 | Kubernetes 1.29 | 叢集架設 + 官方考綱全五域*  
*環境選擇請參考 [README.md](./README.md) | 建議搭配 [killer.sh](https://killer.sh) 模擬考試平台做最終驗收*
