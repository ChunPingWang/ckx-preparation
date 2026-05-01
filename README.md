# Kubernetes CKx 認證實戰練習環境

> **涵蓋 CKA / CKAD / CKS 三種認證**的完整練習環境與題庫

---

## 目錄

1. [練習手冊總覽](#1-練習手冊總覽)
2. [練習環境選擇](#2-練習環境選擇)
3. [方案 A：Vagrant + VirtualBox（x86 / Intel Mac）](#3-方案-avagrant--virtualboxx86--intel-mac)
4. [方案 B：Kind（Mac ARM / Apple Silicon）](#4-方案-bkindmac-arm--apple-silicon)
   - 4.5 [登入 Kind 節點容器](#45-登入-kind-節點容器)
5. [Kind 環境的 RBAC 與 ServiceAccount](#5-kind-環境的-rbac-與-serviceaccount)
6. [專案目錄結構](#6-專案目錄結構)

---

## 1. 練習手冊總覽

| 認證 | 練習手冊 | 內容 |
|------|---------|------|
| **CKA**（Administrator） | [CKA_PRACTICE.md](./CKA_PRACTICE.md) | 叢集架設 + 22 個 Lab + 2 場模擬考 + 快速複習索引 |
| **CKAD**（App Developer） | [CKAD_PRACTICE.md](./CKAD_PRACTICE.md) | 17 個 Lab + 2 場模擬考 |
| **CKS**（Security Specialist）| [CKS_PRACTICE.md](./CKS_PRACTICE.md) | 21 個 Lab + 2 場模擬考 + 速查表 |

- **CKA** 著重叢集架設與管理（含 kubeadm、etcd 備份、叢集升級）
- **CKAD** 著重應用部署與設定（Deployment、Service、ConfigMap 等）
- **CKS** 須先持有 CKA，聚焦安全防護（NetworkPolicy、Pod Security、Audit 等）

---

## 2. 練習環境選擇

根據你的硬體平台選擇適合的方案：

| | 方案 A：Vagrant + VirtualBox | 方案 B：Kind |
|---|---|---|
| **適用平台** | x86 Linux / Windows / Intel Mac | **Mac ARM (M1/M2/M3/M4)** / 任意已裝 Docker 的平台 |
| **架構** | 3 台完整 VM（1 Master + 2 Worker） | Docker 容器模擬多節點叢集 |
| **Host 最低需求** | 8 GB RAM / 4 CPU / 50 GB Disk | 4 GB RAM / 2 CPU / 20 GB Disk |
| **啟動時間** | 10-20 分鐘（首次 provision） | 1-3 分鐘 |
| **CKA 考試擬真度** | 高（完整 kubeadm 流程） | 中（無 kubeadm init/join 流程） |
| **適合認證** | CKA 全考域 | CKAD / CKS / CKA 大部分考域 |

> **Apple Silicon (M1/M2/M3/M4) 使用者**：VirtualBox 不支援 ARM 架構，請使用方案 B（Kind）。

---

## 3. 方案 A：Vagrant + VirtualBox（x86 / Intel Mac）

完整的 Vagrant 多節點叢集架設說明已整合至 **[CKA_PRACTICE.md](./CKA_PRACTICE.md)** 的「叢集架設篇」，包含：

- 版本選擇、架構總覽
- VirtualBox / Vagrant 安裝
- Vagrantfile、common.sh、master_setup.sh、worker_setup.sh 完整說明
- 叢集啟動、驗證、外部存取
- RBAC 設定實戰
- 叢集生命週期管理（pause / resume / destroy）

---

## 4. 方案 B：Kind（Mac ARM / Apple Silicon）

[Kind (Kubernetes IN Docker)](https://kind.sigs.k8s.io/) 使用 Docker 容器模擬 K8s 節點，無需 VM，啟動快速，完美支援 ARM 架構。

### 4.1 前置需求

```bash
# 安裝 Docker Desktop（含 ARM 原生支援）
brew install --cask docker

# 安裝 Kind
brew install kind

# 安裝 kubectl
brew install kubectl

# 驗證
docker version
kind version
kubectl version --client
```

### 4.2 叢集配置檔

本專案在 `kind/` 目錄提供兩種配置：

| 配置檔 | 架構 | 適用場景 |
|--------|------|---------|
| `kind/k8s-mnodes-config.yaml` | 1 Control Plane + 2 Worker | 日常練習（推薦） |
| `kind/k8s-ha-config.yaml` | 3 Control Plane + 3 Worker | HA 叢集練習 |

### 4.3 建立與管理叢集

```bash
# 建立標準叢集（1 Master + 2 Worker）
kind create cluster --config kind/k8s-mnodes-config.yaml --name cka-lab

# 建立 HA 叢集
kind create cluster --config kind/k8s-ha-config.yaml --name cka-ha

# 查看叢集
kind get clusters

# 查看節點（每個節點是一個 Docker 容器）
kubectl get nodes -o wide
docker ps

# 刪除叢集
kind delete cluster --name cka-lab

# 重建叢集（快速重練）
kind delete cluster --name cka-lab && \
kind create cluster --config kind/k8s-mnodes-config.yaml --name cka-lab
```

### 4.4 Kind 與 Vagrant 環境的操作差異

| 操作 | Vagrant 環境 | Kind 環境 |
|------|-------------|-----------|
| 存取叢集 | `vagrant ssh k8s-master` 後操作 | 直接在 Host 執行 `kubectl`（kubeconfig 自動設定） |
| 節點 SSH | `vagrant ssh k8s-node1` | `docker exec -it cka-lab-worker bash` |
| NodePort 存取 | `curl http://192.168.56.11:<port>` | 需在配置檔加 `extraPortMappings`（見下方） |
| 暫停/恢復 | `vagrant suspend / resume` | `docker pause / unpause` 各容器 |
| CNI | Calico（手動安裝） | kindnet（內建，自動安裝） |

#### NodePort 對外存取

若需要從 Host 存取 NodePort Service，修改 Kind 配置檔：

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080    # NodePort
    hostPort: 30080         # Host 上的 port
    protocol: TCP
- role: worker
- role: worker
```

### 4.5 登入 Kind 節點容器

Kind 的每個節點都是一個 Docker 容器，可透過 `docker exec` 登入操作，等同 Vagrant 環境的 `vagrant ssh`。

#### 查看節點容器名稱

```bash
# 列出所有 Kind 節點容器
docker ps --filter "label=io.x-k8s.kind.cluster=cka-lab" --format "table {{.Names}}\t{{.Status}}"

# 預期輸出（以 k8s-mnodes-config.yaml 為例）：
# NAMES                    STATUS
# cka-lab-control-plane    Up 10 minutes
# cka-lab-worker           Up 10 minutes
# cka-lab-worker2          Up 10 minutes
```

#### 登入節點

```bash
# 登入 Control Plane 節點
docker exec -it cka-lab-control-plane bash

# 登入 Worker Node
docker exec -it cka-lab-worker bash
docker exec -it cka-lab-worker2 bash
```

#### 節點內常用操作

登入後即為 root 身份，可直接執行系統指令：

```bash
# ── 查看系統服務 ──────────────────────────────────────────
systemctl status kubelet          # kubelet 狀態
journalctl -u kubelet --no-pager -n 50   # kubelet 日誌

# ── 容器除錯（crictl）────────────────────────────────────
crictl ps                         # 列出正在運行的容器
crictl pods                       # 列出所有 Pod
crictl logs <container-id>        # 查看容器日誌
crictl images                     # 列出已下載的映像

# ── 查看 Static Pod manifest（僅 Control Plane）──────────
ls /etc/kubernetes/manifests/
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

cat /etc/kubernetes/manifests/kube-apiserver.yaml

# ── 查看 kubelet 設定 ────────────────────────────────────
cat /var/lib/kubelet/config.yaml

# ── 網路除錯 ─────────────────────────────────────────────
ip addr                           # 查看網路介面
ip route                          # 查看路由表
iptables -t nat -L KUBE-SERVICES  # 查看 Service 的 iptables 規則

# ── 離開節點 ─────────────────────────────────────────────
exit
```

#### 在節點容器內執行單一指令（不登入）

```bash
# 查看 Control Plane 的 kubelet 狀態
docker exec cka-lab-control-plane systemctl status kubelet

# 查看 Worker 的 containerd 版本
docker exec cka-lab-worker containerd --version

# 查看 etcd manifest
docker exec cka-lab-control-plane cat /etc/kubernetes/manifests/etcd.yaml

# 模擬 kubelet 故障（Lab 練習用）
docker exec cka-lab-worker systemctl stop kubelet

# 恢復 kubelet
docker exec cka-lab-worker systemctl start kubelet
```

#### 在節點間複製檔案

```bash
# 從 Host 複製檔案到節點容器
docker cp ./my-config.yaml cka-lab-control-plane:/tmp/my-config.yaml

# 從節點容器複製檔案到 Host
docker cp cka-lab-control-plane:/etc/kubernetes/admin.conf ./admin.conf
```

#### Kind 節點與 VM 節點的差異

| 操作 | Vagrant VM | Kind 容器 |
|------|-----------|-----------|
| 登入方式 | `vagrant ssh k8s-master` | `docker exec -it cka-lab-control-plane bash` |
| 使用者身份 | vagrant（需 `sudo`） | **root**（直接操作，無需 sudo） |
| 單指令執行 | `vagrant ssh k8s-master -c "cmd"` | `docker exec cka-lab-control-plane cmd` |
| 檔案傳輸 | `/vagrant` 共享目錄 | `docker cp` |
| 服務管理 | `systemctl`（完整 systemd） | `systemctl`（Kind 容器內含 systemd） |
| 重開機 | `vagrant reload k8s-master` | `docker restart cka-lab-control-plane` |

---

### 4.6 安裝 CNI Plugin（NetworkPolicy 練習用）

Kind 預設使用 kindnet，**不支援 NetworkPolicy**。若需練習 NetworkPolicy（CKA/CKS 考點），需改裝 Calico：

```bash
# 建立叢集時停用預設 CNI
cat <<EOF | kind create cluster --config - --name cka-netpol
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true    # 停用 kindnet
  podSubnet: 192.168.0.0/16  # Calico 預設 CIDR
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# 安裝 Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# 等待就緒
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=180s
```

---

## 5. Kind 環境的 RBAC 與 ServiceAccount

> **結論：Kind 叢集的 RBAC 與 ServiceAccount 機制和標準 K8s 完全一致，不需要額外設定。**

### 5.1 RBAC 預設行為

Kind 叢集啟動後，RBAC 授權模式 (`--authorization-mode=RBAC,Node`) 已預設啟用，與 kubeadm 建立的叢集行為一致：

- `system:*` 相關的 ClusterRole / ClusterRoleBinding 已自動建立
- `admin`、`edit`、`view` 等內建 ClusterRole 可直接使用
- `kube-system` namespace 的 ServiceAccount 已有適當權限

```bash
# 驗證 RBAC 已啟用
kubectl api-versions | grep rbac
# 預期輸出：rbac.authorization.k8s.io/v1

# 查看內建 ClusterRole
kubectl get clusterrole | head -20

# 建立 RBAC 資源（與 Vagrant 環境完全相同）
kubectl create namespace dev
kubectl create serviceaccount dev-developer -n dev
kubectl create role developer-role \
  --verb=get,list,watch,create,delete \
  --resource=pods,deployments \
  --namespace=dev
kubectl create rolebinding developer-binding \
  --role=developer-role \
  --serviceaccount=dev:dev-developer \
  --namespace=dev

# 驗證
kubectl auth can-i list pods -n dev \
  --as=system:serviceaccount:dev:dev-developer
# yes
```

### 5.2 ServiceAccount 注意事項

K8s 1.24+ 後（Kind 預設使用較新版本），ServiceAccount Token 的行為有以下變化：

| 版本 | Token 行為 |
|------|-----------|
| K8s < 1.24 | 建立 SA 時自動產生永久 Secret Token |
| K8s >= 1.24 | **不再自動產生** Secret Token；改用 TokenRequest API 發行短期 Token |

```bash
# 若需要長期 Token（例如 CI/CD 用途），需手動建立 Secret：
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dev-developer-token
  namespace: dev
  annotations:
    kubernetes.io/service-account.name: dev-developer
type: kubernetes.io/service-account-token
EOF

# 取得 Token
kubectl get secret dev-developer-token -n dev -o jsonpath='{.data.token}' | base64 -d
```

### 5.3 Kind 環境不可練習的 CKA 考點

以下考點依賴完整的 kubeadm 流程或 VM 環境，Kind 無法模擬：

| 考點 | 原因 | 替代方式 |
|------|------|---------|
| `kubeadm init / join` | Kind 叢集由 Kind CLI 建立，非 kubeadm | 閱讀理解 + Vagrant 環境實操 |
| `kubeadm upgrade` | 同上 | 閱讀理解 |
| etcd 備份還原 | Mac ARM 上 etcdctl 會因模擬層問題 crash（見下方說明） | 改用 `kubectl exec` 方式操作，或在 Host 端執行 |
| kubelet 故障修復 | Kind 節點是 Docker 容器，`systemctl` 行為不同 | 可 `docker exec` 進入容器練習 |
| Static Pod manifest 修改 | 路徑存在但 kubelet 行為略有差異 | 可練習，效果接近 |

> 上述考點合計約佔 CKA 考試的 10-15%。其餘 85-90% 的考點（RBAC、Deployment、Service、NetworkPolicy、PV/PVC、故障排查等）在 Kind 環境下均可完整練習。

### 5.4 Mac ARM 上的 etcd 備份練習

在 Mac ARM (Apple Silicon) 上，Kind 節點容器內的 `etcdctl` 是 x86 binary，透過 Rosetta/QEMU 模擬執行。執行 `etcdctl snapshot save` 時可能觸發以下錯誤：

```
runtime: lfstack.push invalid packing: node=0xffff58bc7080 ...
fatal error: lfstack.push
```

這是 **Go runtime 在 x86 模擬層的已知問題**，與你的操作或叢集狀態無關。

#### 為什麼 kubectl exec 進 etcd Pod 也不行？

etcd Pod 使用 [distroless](https://github.com/GoogleContainerTools/distroless) 映像，容器內**只有 etcd 相關 binary**，沒有 `ls`、`sh`、`bash` 等任何 shell 工具。因此 `kubectl exec` 無法在 etcd Pod 內執行任意指令：

```
# 這行會失敗：
kubectl exec -n kube-system etcd-kind-control-plane -- ls /var/lib/etcd
# error: "ls": executable file not found in $PATH
```

#### 替代方案：在 Host 安裝 ARM 原生 etcdctl

在 Mac 上安裝 ARM 原生版本的 etcdctl，透過 Docker network 直接連線到 Kind 容器內的 etcd：

```bash
# ── Step 1：安裝 ARM 原生 etcdctl ────────────────────────
brew install etcd

# 確認版本（應為 darwin/arm64）
etcdctl version

# ── Step 2：從 Kind 容器複製 etcd 憑證到 Host ────────────
mkdir -p /tmp/etcd-certs
docker cp kind-control-plane:/etc/kubernetes/pki/etcd/ca.crt /tmp/etcd-certs/
docker cp kind-control-plane:/etc/kubernetes/pki/etcd/server.crt /tmp/etcd-certs/
docker cp kind-control-plane:/etc/kubernetes/pki/etcd/server.key /tmp/etcd-certs/

# ── Step 3：取得 Kind 容器的 IP ──────────────────────────
ETCD_IP=$(docker inspect kind-control-plane \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "etcd IP: ${ETCD_IP}"

# ── Step 4：執行備份 ─────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot save ./etcd-snapshot.db \
  --endpoints=https://${ETCD_IP}:2379 \
  --cacert=/tmp/etcd-certs/ca.crt \
  --cert=/tmp/etcd-certs/server.crt \
  --key=/tmp/etcd-certs/server.key

# ── Step 5：驗證備份 ─────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot status ./etcd-snapshot.db --write-out=table

# 預期輸出（範例）：
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | a1b2c3d4 |     1234 |        512 |    2.5 MB  |
# +----------+----------+------------+------------+

# ── Step 6：還原練習 ─────────────────────────────────────
# 還原到本地目錄（練習指令流程）
ETCDCTL_API=3 etcdctl snapshot restore ./etcd-snapshot.db \
  --data-dir=/tmp/etcd-restore
ls /tmp/etcd-restore/   # 確認還原資料
```

> **注意**：叢集名稱不同時，容器名稱也不同。請用 `docker ps --filter "label=io.x-k8s.kind.role=control-plane"` 確認實際名稱（例如 `kind-control-plane`、`cka-lab-control-plane` 等）。

> **CKA 考試提醒**：實際考試環境為 x86 Linux VM，etcdctl 直接在節點上執行即可，不會遇到 ARM 模擬層或 distroless 映像的問題。此處的替代方案僅用於在 Mac ARM 上練習 etcd 操作指令與流程。

---

## 6. 專案目錄結構

```
ckx-preparation/
├── README.md                # 本文件（總覽與環境選擇）
├── CKA_PRACTICE.md          # CKA 叢集架設 + 22 Labs + 2 模擬考
├── CKAD_PRACTICE.md         # CKAD 17 Labs + 2 模擬考
├── CKS_PRACTICE.md          # CKS 21 Labs + 2 模擬考
├── Vagrantfile              # 方案 A：VM 定義（1 Master + 2 Worker）
├── scripts/                 # 方案 A：Vagrant provision 腳本
│   ├── common.sh            # 所有 VM 共用：containerd + kubeadm
│   ├── master_setup.sh      # Control Plane：kubeadm init + Calico
│   ├── worker_setup.sh      # Worker Node：kubeadm join
│   ├── pause-cluster.sh     # Host 端：暫停叢集
│   └── resume-cluster.sh    # Host 端：恢復叢集
└── kind/                    # 方案 B：Kind 叢集配置
    ├── k8s-mnodes-config.yaml  # 1 Master + 2 Worker（推薦）
    └── k8s-ha-config.yaml      # 3 Master + 3 Worker（HA）
```

---

*Kubernetes CKx 認證練習環境 | 支援 CKA / CKAD / CKS*
