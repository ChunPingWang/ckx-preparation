# CKS 全題型實戰練習手冊
## Certified Kubernetes Security Specialist

> **考試定位**：K8s 安全專家認證，**前置條件：必須先持有 CKA**  
> **考試時長**：2 小時｜**及格分數**：67%  
> **核心精神**：Defense in Depth（縱深防禦）— 每一層都要設防

```
CKS 考域分布（2024-2025）：
┌──────────────────────────────────────────────────┬──────┐
│ Cluster Setup                                    │  10% │
│ Cluster Hardening                                │  15% │
│ System Hardening                                 │  15% │
│ Minimize Microservice Vulnerabilities            │  20% │
│ Supply Chain Security                            │  20% │
│ Monitoring, Logging and Runtime Security         │  20% │
└──────────────────────────────────────────────────┴──────┘

縱深防禦示意：
┌─────────────────────────────────────────────────────┐
│  Supply Chain  │ 映像掃描、Dockerfile 最佳實踐        │
│  Cluster Setup │ CIS Benchmark、API Server 安全設定   │
│  Hardening     │ RBAC 最小權限、Network Policy        │
│  Runtime       │ Falco、AppArmor、Seccomp、Audit Log  │
└─────────────────────────────────────────────────────┘
```

---

## 目錄

### Domain 1：叢集設定（10%）
- [Lab 01 🟡 CIS Benchmark 合規掃描](#lab-01-cis-benchmark-合規掃描)
- [Lab 02 🔴 API Server 安全加固](#lab-02-api-server-安全加固)
- [Lab 03 🟡 Ingress TLS 與安全標頭](#lab-03-ingress-tls-與安全標頭)

### Domain 2：叢集加固（15%）
- [Lab 04 🟡 RBAC 最小權限原則](#lab-04-rbac-最小權限原則)
- [Lab 05 🔴 ServiceAccount 安全加固](#lab-05-serviceaccount-安全加固)
- [Lab 06 🟡 etcd 靜態加密](#lab-06-etcd-靜態加密)
- [Lab 07 🟡 K8s 版本與 CVE 管理](#lab-07-k8s-版本與-cve-管理)

### Domain 3：系統加固（15%）
- [Lab 08 🔴 AppArmor Profile](#lab-08-apparmor-profile)
- [Lab 09 🟡 Seccomp Profile](#lab-09-seccomp-profile)
- [Lab 10 🟢 Linux Capability 限制](#lab-10-linux-capability-限制)

### Domain 4：最小化微服務漏洞（20%）
- [Lab 11 🟡 Pod Security Standards 嚴格模式](#lab-11-pod-security-standards-嚴格模式)
- [Lab 12 🔴 OPA Gatekeeper 策略引擎](#lab-12-opa-gatekeeper-策略引擎)
- [Lab 13 🟡 Secret 安全管理](#lab-13-secret-安全管理)
- [Lab 14 🟡 mTLS 服務間加密](#lab-14-mtls-服務間加密)

### Domain 5：供應鏈安全（20%）
- [Lab 15 🟡 容器映像掃描：Trivy](#lab-15-容器映像掃描trivy)
- [Lab 16 🟡 映像簽名與驗證](#lab-16-映像簽名與驗證)
- [Lab 17 🔴 Admission Controller：ImagePolicyWebhook](#lab-17-admission-controllerimagepolicywebhook)
- [Lab 18 🟢 安全的 Dockerfile 實踐](#lab-18-安全的-dockerfile-實踐)

### Domain 6：監控、日誌與運行時安全（20%）
- [Lab 19 🔴 Falco 異常行為偵測](#lab-19-falco-異常行為偵測)
- [Lab 20 🔴 Kubernetes Audit Log](#lab-20-kubernetes-audit-log)
- [Lab 21 🟡 運行時異常事件調查](#lab-21-運行時異常事件調查)

### 綜合模擬
- [Mock Exam 01：CKS 45 分鐘模擬](#cks-mock-exam-01)
- [Mock Exam 02：CKS 45 分鐘模擬](#cks-mock-exam-02)

---

# Domain 1：叢集設定

---

## Lab 01 CIS Benchmark 合規掃描

> 🟡 Medium｜考域 10%｜預估時間：15 分鐘

### CIS Kubernetes Benchmark 說明

```
CIS（Center for Internet Security）發布的 K8s 安全基準
涵蓋：Master Node、Worker Node、Policy 三大類別
工具：kube-bench 自動化掃描
```

### 練習題

**題目 1**：安裝並執行 kube-bench，理解輸出結果

**題目 2**：根據 kube-bench 建議修復 API Server 設定

### 解題步驟

```bash
# ── 安裝 kube-bench ───────────────────────────────────────
vagrant ssh k8s-master

# 下載 kube-bench
curl -fsSL https://github.com/aquasecurity/kube-bench/releases/download/v0.7.0/kube-bench_0.7.0_linux_amd64.tar.gz \
  | tar xz -C /usr/local/bin kube-bench

# ── 執行 CIS Benchmark 掃描 ───────────────────────────────
# 掃描 Master 節點
sudo kube-bench run --targets master \
  --config-dir /etc/kube-bench \
  --config /etc/kube-bench/config.yaml \
  2>/dev/null | tee /tmp/cis-master-report.txt

# 掃描 Worker 節點（在 node 上執行）
# sudo kube-bench run --targets node

# ── 理解輸出格式 ──────────────────────────────────────────
# [PASS] - 符合 CIS 標準
# [FAIL] - 不符合，需修復
# [WARN] - 警告，需人工審查
# [INFO] - 參考資訊

# 統計各狀態數量
grep -c "\[PASS\]" /tmp/cis-master-report.txt
grep -c "\[FAIL\]" /tmp/cis-master-report.txt
grep -c "\[WARN\]" /tmp/cis-master-report.txt

# 只顯示失敗項目
grep "\[FAIL\]" /tmp/cis-master-report.txt

# ── 常見 FAIL 項目說明 ─────────────────────────────────────
# 1.2.1 確保 --anonymous-auth=false
# 1.2.5 確保 --kubelet-certificate-authority 已設定
# 1.2.7 確保 --authorization-mode 不包含 AlwaysAllow

# ── 在 kube-bench 容器中執行（不需安裝到主機）─────────────
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench-master
spec:
  template:
    spec:
      hostPID: true
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      - name: usr-local-mount-1
        hostPath:
          path: "/usr/local/mount-from-host/bin"
      restartPolicy: Never
      containers:
      - name: kube-bench
        image: docker.io/aquasec/kube-bench:latest
        command: ["kube-bench", "run", "--targets", "master"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        securityContext:
          privileged: true
EOF

kubectl logs -l job-name=kube-bench-master | grep "\[FAIL\]"
```

---

## Lab 02 API Server 安全加固

> 🔴 Hard｜考域 10%｜預估時間：20 分鐘  
> **風險警告**：修改此檔案可能導致叢集停擺，**務必備份**

### 關鍵安全設定

```
/etc/kubernetes/manifests/kube-apiserver.yaml 是 Static Pod manifest
修改後 kubelet 自動重啟，無效設定會導致 API Server 無法啟動
```

### 練習題

**題目 1**：停用匿名存取，設定安全 admission plugins

**題目 2**：啟用 Node Restriction Admission Plugin

### 解題步驟

```bash
vagrant ssh k8s-master

# ── 備份（必要！）────────────────────────────────────────
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /root/kube-apiserver.yaml.bak

# ── 查看當前設定 ──────────────────────────────────────────
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | \
  grep -E "anonymous|authorization|admission"

# ── 修改 API Server 安全設定 ──────────────────────────────
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

# 找到 containers.command 區塊，加入或修改以下參數：
```

```yaml
# 在 kube-apiserver.yaml 的 command 區塊加入：
- --anonymous-auth=false              # 禁止匿名存取
- --authorization-mode=Node,RBAC     # 移除 AlwaysAllow（若存在）
- --enable-admission-plugins=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
- --disable-admission-plugins=AlwaysAdmit  # 明確禁用不安全 plugin
- --profiling=false                   # 禁用 profiling endpoint
- --audit-log-path=/var/log/kubernetes/audit.log  # 啟用 audit log
- --audit-log-maxage=30              # 保留 30 天
- --audit-log-maxbackup=10           # 最多 10 個備份檔
- --audit-log-maxsize=100            # 每個檔案最大 100MB
- --request-timeout=300s             # 請求超時
- --tls-min-version=VersionTLS12     # 最低 TLS 1.2
```

```bash
# 等待 API Server 重啟
sleep 30
kubectl get nodes  # 確認正常

# 驗證匿名存取被禁止
curl -k https://192.168.56.10:6443/api
# 預期：{"kind":"Status",...,"code":401}  (Unauthorized)

# 驗證 admission plugins
kubectl get pod kube-apiserver-k8s-master -n kube-system -o yaml | \
  grep enable-admission
```

---

## Lab 03 Ingress TLS 與安全標頭

> 🟡 Medium｜考域 10%｜預估時間：12 分鐘

```bash
# ── 建立強化的 TLS Ingress ────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    # 強制 HTTPS 重導
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # 安全標頭（防止常見 Web 攻擊）
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    # 限制 TLS 版本（只允許 TLS 1.2+）
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
    # 速率限制（防 DDoS）
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: secure-tls
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
EOF
```

---

# Domain 2：叢集加固

---

## Lab 04 RBAC 最小權限原則

> 🟡 Medium｜考域 15%｜預估時間：15 分鐘

### 最小權限（Least Privilege）原則

```
每個 ServiceAccount / User 只能取得完成工作所需的最低權限
不使用 cluster-admin 除非絕對必要
定期審查並清理未使用的 RBAC 規則
```

### 練習題

**題目 1**：審查現有 ClusterRoleBinding，找出過寬的權限

**題目 2**：修復一個被過度授權的 ServiceAccount

**題目 3**：偵測並移除危險的 RBAC 設定

### 解題步驟

```bash
# ── 題目 1：審查過寬權限 ──────────────────────────────────
# 找出所有綁定 cluster-admin 的對象
kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}'

# 找出有 * 動詞（萬用）的 ClusterRole
kubectl get clusterrole -o json | \
  jq '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'

# 找出可以存取 Secrets 的 Role（高風險）
kubectl get role,clusterrole -A -o json | \
  jq '.items[] | select(.rules[]?.resources[]? == "secrets") | 
    {ns: .metadata.namespace, name: .metadata.name}'

# ── 題目 2：修復過度授權 ──────────────────────────────────
# 模擬問題：某 SA 被錯誤授予 cluster-admin
kubectl create serviceaccount over-privileged-sa
kubectl create clusterrolebinding bad-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=default:over-privileged-sa

# 驗證問題（SA 可以刪除 Node！）
kubectl auth can-i delete nodes \
  --as=system:serviceaccount:default:over-privileged-sa
# 預期：yes（這是問題）

# 修復：刪除危險 binding，改用最小權限
kubectl delete clusterrolebinding bad-binding

# 重新授予最小所需權限
kubectl create role minimal-role \
  --verb=get,list \
  --resource=configmaps \
  --namespace=default

kubectl create rolebinding minimal-binding \
  --role=minimal-role \
  --serviceaccount=default:over-privileged-sa \
  --namespace=default

# 驗證修復
kubectl auth can-i delete nodes \
  --as=system:serviceaccount:default:over-privileged-sa
# 預期：no

# ── 題目 3：偵測危險 RBAC ─────────────────────────────────
# 危險組合：可以建立 Pod（可能掛載 /etc、hostPID 等）
kubectl get role,clusterrole -A -o json | \
  jq '.items[] | select(
    (.rules[]?.resources[]? == "pods") and
    (.rules[]?.verbs[]? == "create")
  ) | {ns: .metadata.namespace, name: .metadata.name}'

# 危險：可以 impersonate（模擬其他 user）
kubectl get clusterrole -o json | \
  jq '.items[] | select(.rules[]?.resources[]? == "users" and 
    .rules[]?.verbs[]? == "impersonate") | .metadata.name'
```

---

## Lab 05 ServiceAccount 安全加固

> 🔴 Hard｜考域 15%｜預估時間：15 分鐘

```bash
# ── 安全最佳實踐：禁用自動掛載 Token ─────────────────────

# 在 Namespace 層級：新建 SA 預設不掛載 token
# （每個 SA 需明確設定 automountServiceAccountToken: false）

# 方式 1：SA 層級設定
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: default
automountServiceAccountToken: false   # SA 層級禁用
EOF

# 方式 2：Pod 層級覆蓋（比 SA 層級優先）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
spec:
  serviceAccountName: restricted-sa
  automountServiceAccountToken: false   # Pod 層級也禁用
  containers:
  - name: app
    image: nginx:alpine
EOF

# 驗證：Pod 內沒有 token
kubectl exec no-token-pod -- ls /var/run/secrets/ 2>&1
# 預期：No such file or directory

# ── 短效 Token 最佳實踐（K8s 1.24+）─────────────────────
# 使用 TokenRequest API 取得短效 token
kubectl create token restricted-sa \
  --duration=1h \           # 1 小時後過期
  --namespace=default

# 使用 Projected Volume 掛載短效 token（生命週期與 Pod 綁定）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: projected-token-pod
spec:
  serviceAccountName: restricted-sa
  automountServiceAccountToken: false   # 禁用自動掛載
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600      # 1 小時過期
          audience: "my-api-server"    # 限制 token 受眾
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: token
      mountPath: /var/run/secrets/tokens
      readOnly: true
EOF

kubectl exec projected-token-pod -- \
  cat /var/run/secrets/tokens/token | cut -d. -f2 | base64 -d 2>/dev/null
# 可看到 JWT payload（含 exp 過期時間）

# ── 找出並清理未使用的 SA ─────────────────────────────────
# 列出所有 SA
kubectl get serviceaccounts -A

# 找出沒有對應 RoleBinding 的 SA（可能是遺留的）
kubectl get serviceaccounts -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | \
  while read sa; do
    ns=$(echo $sa | cut -d/ -f1)
    name=$(echo $sa | cut -d/ -f2)
    bindings=$(kubectl get rolebinding,clusterrolebinding -A -o json 2>/dev/null | \
      jq --arg ns "$ns" --arg name "$name" \
      '[.items[].subjects[]? | select(.kind=="ServiceAccount" and .name==$name and .namespace==$ns)] | length')
    [ "$bindings" = "0" ] && echo "Unused SA: $sa"
  done
```

---

## Lab 06 etcd 靜態加密

> 🟡 Medium｜考域 15%｜預估時間：15 分鐘

### 為什麼需要 etcd 加密？

```
etcd 儲存所有 K8s 資料，包含 Secret
預設情況下，Secret 在 etcd 中是 base64 編碼（非加密！）
攻擊者取得 etcd 備份 → 解 base64 → 取得所有 Secret

靜態加密（Encryption at Rest）確保 etcd 資料即使被竊，
未持有金鑰也無法讀取。
```

### 解題步驟

```bash
vagrant ssh k8s-master

# ── Step 1：確認目前 Secret 未加密 ────────────────────────
kubectl create secret generic test-secret \
  --from-literal=password=SuperSecret123

# 直接從 etcd 讀取（未加密）
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/test-secret | hexdump -C | grep -i password

# 可以看到明文 password 值 → 這就是問題

# ── Step 2：建立加密設定 ──────────────────────────────────
# 產生 32 byte 亂數金鑰（AES-CBC）
AES_KEY=$(head -c 32 /dev/urandom | base64)
echo "Generated key: ${AES_KEY}"

sudo mkdir -p /etc/kubernetes/encryption

sudo cat > /etc/kubernetes/encryption/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets               # 加密 Secret 資源
  - configmaps            # 也可加密 ConfigMap（選擇性）
  providers:
  - aescbc:               # AES-CBC 加密（CKS 考試常用）
      keys:
      - name: key1
        secret: ${AES_KEY}
  - identity: {}          # Fallback：不加密（用於讀取舊資料）
  # 注意：providers 順序決定寫入和讀取方式
  # 第一個 provider 用於寫入，所有 provider 用於讀取
EOF

# ── Step 3：設定 API Server 使用加密設定 ──────────────────
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /root/kube-apiserver-pre-encrypt.yaml.bak

# 在 kube-apiserver.yaml 的 command 加入：
# - --encryption-provider-config=/etc/kubernetes/encryption/encryption-config.yaml

# 在 volumeMounts 加入：
# - mountPath: /etc/kubernetes/encryption
#   name: encryption-config
#   readOnly: true

# 在 volumes 加入：
# - hostPath:
#     path: /etc/kubernetes/encryption
#     type: DirectoryOrCreate
#   name: encryption-config

sudo sed -i '/--etcd-servers/a\    - --encryption-provider-config=/etc/kubernetes/encryption/encryption-config.yaml' \
  /etc/kubernetes/manifests/kube-apiserver.yaml

# ── Step 4：驗證加密生效 ──────────────────────────────────
sleep 30  # 等待 API Server 重啟

# 強制重新加密現有 Secret（update 觸發重寫）
kubectl get secrets -A -o json | \
  kubectl replace -f -

# 從 etcd 確認現在已加密
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/test-secret | hexdump -C | head -5

# 預期看到：k8s:enc:aescbc:v1:key1:... （加密後的亂碼）
# 不應再看到明文 password
```

---

## Lab 07 K8s 版本與 CVE 管理

> 🟡 Medium｜考域 15%｜預估時間：10 分鐘

```bash
# ── 查看目前版本與 CVE 公告 ───────────────────────────────
kubectl version
kubectl get nodes -o wide

# K8s CVE 資料庫
# https://www.cvedetails.com/vendor/15867/Kubernetes.html
# https://kubernetes.io/docs/reference/issues-security/official-cve-feed/

# ── 使用 kubectl-who-can 審查權限 ─────────────────────────
# 安裝 who-can 插件
curl -fsSL https://github.com/aquasecurity/kubectl-who-can/releases/latest/download/kubectl-who-can_linux_x86_64.tar.gz \
  | tar xz -C /usr/local/bin

# 誰能讀取 Secrets？
kubectl who-can get secrets -n default
kubectl who-can create pods -n kube-system  # 高危！

# ── 查看 API Server audit log 找異常 ──────────────────────
sudo tail -50 /var/log/kubernetes/audit.log | \
  python3 -c "import sys,json; [print(json.dumps(json.loads(l), indent=2)) for l in sys.stdin]" 2>/dev/null | \
  grep -A 5 '"verb":"delete"'
```

---

# Domain 3：系統加固

---

## Lab 08 AppArmor Profile

> 🔴 Hard｜考域 15%｜預估時間：20 分鐘

### AppArmor 說明

```
AppArmor 是 Linux 強制存取控制（MAC）系統
為程序定義允許/禁止的系統呼叫和資源存取
K8s 透過 Pod annotation 套用 AppArmor profile
```

### 解題步驟

```bash
# ── Step 1：在每個節點安裝 AppArmor 工具 ─────────────────
vagrant ssh k8s-node1

sudo apt-get install -y apparmor-utils apparmor-profiles

# 查看已載入的 profiles
sudo apparmor_status
# 會顯示 enforce/complain mode 的 profiles

# ── Step 2：建立自定義 AppArmor Profile ──────────────────
# Profile 必須在 Pod 要執行的節點上存在

sudo cat > /etc/apparmor.d/k8s-nginx-restricted <<'EOF'
#include <tunables/global>

profile k8s-nginx-restricted flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # 允許讀取必要的系統檔案
  file,

  # 允許網路（nginx 需要）
  network inet tcp,
  network inet udp,

  # 禁止寫入敏感目錄
  deny /etc/passwd w,
  deny /etc/shadow w,
  deny /root/** w,

  # 禁止執行任意程式
  deny /usr/bin/wget x,
  deny /usr/bin/curl x,

  # 允許 nginx 的必要 capabilities
  capability net_bind_service,
  capability setuid,
  capability setgid,

  # 禁止危險 capabilities
  deny capability sys_admin,
  deny capability sys_ptrace,
  deny capability net_raw,
}
EOF

# 載入 profile（enforce mode）
sudo apparmor_parser -r /etc/apparmor.d/k8s-nginx-restricted

# 確認已載入
sudo apparmor_status | grep k8s-nginx

exit  # 回到 master

# ── Step 3：在 Pod 套用 AppArmor Profile ─────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  annotations:
    # 格式：container.apparmor.security.beta.kubernetes.io/<container-name>
    container.apparmor.security.beta.kubernetes.io/nginx: localhost/k8s-nginx-restricted
spec:
  nodeName: k8s-node1   # 確保排到有 profile 的節點
  containers:
  - name: nginx
    image: nginx:alpine
EOF

# K8s 1.30+ 使用 securityContext（不再需要 annotation）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod-v2
spec:
  nodeName: k8s-node1
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-nginx-restricted
  containers:
  - name: nginx
    image: nginx:alpine
EOF

# 驗證 profile 已套用
kubectl exec apparmor-pod -- cat /proc/1/attr/current
# 預期：k8s-nginx-restricted (enforce)

# 測試限制生效（嘗試被禁止的操作）
kubectl exec apparmor-pod -- wget -q google.com 2>&1
# 預期：Permission denied（wget 被 deny）
```

---

## Lab 09 Seccomp Profile

> 🟡 Medium｜考域 15%｜預估時間：15 分鐘

### Seccomp 說明

```
Seccomp（Secure Computing Mode）限制程序可使用的系統呼叫
減少攻擊面：即使容器被入侵，也無法呼叫危險的 syscall

三種 profile 類型：
- Unconfined：不限制（預設，不安全）
- RuntimeDefault：containerd/runc 的預設安全 profile
- Localhost：自定義 profile（最嚴格）
```

### 解題步驟

```bash
vagrant ssh k8s-node1

# ── Step 1：建立自定義 Seccomp Profile ───────────────────
sudo mkdir -p /var/lib/kubelet/seccomp/profiles

sudo cat > /var/lib/kubelet/seccomp/profiles/nginx-restricted.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": [
        "accept4", "access", "arch_prctl", "bind", "brk",
        "capget", "capset", "chdir", "chmod", "chown",
        "clone", "close", "connect", "dup", "dup2",
        "epoll_create", "epoll_create1", "epoll_ctl", "epoll_pwait",
        "epoll_wait", "eventfd2", "execve", "exit", "exit_group",
        "faccessat", "fadvise64", "fallocate", "fchdir", "fchmod",
        "fchmodat", "fchown", "fchownat", "fcntl", "fdatasync",
        "fgetxattr", "flistxattr", "flock", "fstat", "fstatfs",
        "fsync", "ftruncate", "futex", "getcwd", "getdents64",
        "getegid", "geteuid", "getgid", "getgroups", "getpgid",
        "getpid", "getppid", "getpriority", "getrandom",
        "getrlimit", "getrusage", "getsid", "getsockname",
        "getsockopt", "getuid", "io_setup", "ioctl",
        "kill", "lgetxattr", "link", "linkat", "listen",
        "lseek", "lstat", "madvise", "memfd_create",
        "mkdir", "mkdirat", "mlock", "mmap", "mount",
        "mprotect", "mremap", "munmap", "nanosleep",
        "newfstatat", "open", "openat", "pause", "pipe",
        "pipe2", "poll", "ppoll", "prctl", "pread64",
        "preadv", "prlimit64", "pselect6", "pwrite64",
        "pwritev", "read", "readlink", "readlinkat", "readv",
        "recv", "recvfrom", "recvmsg", "rename", "renameat",
        "renameat2", "rmdir", "rt_sigaction", "rt_sigpending",
        "rt_sigprocmask", "rt_sigreturn", "rt_sigsuspend",
        "rt_sigtimedwait", "sched_getaffinity", "sched_yield",
        "seccomp", "select", "send", "sendfile", "sendmsg",
        "sendto", "set_robust_list", "set_tid_address",
        "setfsgid", "setfsuid", "setgid", "setgroups",
        "setitimer", "setpgid", "setresgid", "setresuid",
        "setrlimit", "setsid", "setsockopt", "setuid",
        "setxattr", "sigaltstack", "socket", "socketpair",
        "stat", "statfs", "statx", "symlink", "symlinkat",
        "tgkill", "time", "timer_create", "timer_delete",
        "timer_getoverrun", "timer_gettime", "timer_settime",
        "timerfd_create", "timerfd_gettime", "timerfd_settime",
        "tkill", "truncate", "umask", "uname", "unlink",
        "unlinkat", "utime", "utimensat", "utimes",
        "wait4", "waitid", "write", "writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

exit  # 回到 master

# ── Step 2：在 Pod 套用 Seccomp ───────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost               # 使用自定義 profile
      localhostProfile: profiles/nginx-restricted.json  # 相對於 /var/lib/kubelet/seccomp/
  containers:
  - name: nginx
    image: nginx:alpine
EOF

# 使用 RuntimeDefault（最安全的預設值，CKS 考試推薦）
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime-default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault    # 使用 containerd 的預設 seccomp profile
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

# 驗證 seccomp 已套用
kubectl exec seccomp-runtime-default -- \
  cat /proc/1/status | grep Seccomp
# Seccomp: 2  (2=filter mode = seccomp 已啟用)
```

---

## Lab 10 Linux Capability 限制

> 🟢 Easy｜考域 15%｜預估時間：10 分鐘

```bash
# ── 理解 Linux Capabilities ───────────────────────────────
# 傳統：root 有全部權限，non-root 全無
# Capabilities：將 root 權限細分為獨立單元
# 容器預設有部分 capabilities（如 CHOWN、NET_BIND_SERVICE）

# 查看容器預設 capabilities
kubectl run cap-test --image=alpine --rm -it --restart=Never -- \
  sh -c "apk add libcap && capsh --print"

# ── 最小 Capability 設定 ─────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minimal-caps
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      capabilities:
        drop:
        - ALL            # 先刪除所有 capabilities
        add:
        - NET_BIND_SERVICE  # 只保留需要的（綁定 <= 1024 port）
        # 其他常見必要 capability：
        # CHOWN          → 改變檔案所有者
        # SETUID/SETGID  → 切換 UID/GID
        # NET_ADMIN      → 網路管理（高危，避免給）
        # SYS_ADMIN      → 幾乎等同 root（絕對禁止）
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
EOF

# ── 危險 Capability 說明 ──────────────────────────────────
# 以下 capabilities 在 CKS 考試中必須了解其風險：
# SYS_ADMIN   → 幾乎無限制（掛載、namespace 操作等）
# SYS_PTRACE  → 跨程序 debug（可竊取其他容器記憶體）
# NET_ADMIN   → 修改路由表、iptables
# NET_RAW     → 建立 raw socket（可進行 ARP/ICMP 欺騙）
# SYS_CHROOT  → chroot 系統呼叫
```

---

# Domain 4：最小化微服務漏洞

---

## Lab 11 Pod Security Standards 嚴格模式

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

```bash
# ── Restricted Profile 要求清單 ──────────────────────────
# ✅ runAsNonRoot: true
# ✅ runAsUser: (非 0)
# ✅ allowPrivilegeEscalation: false
# ✅ seccompProfile: RuntimeDefault 或 Localhost
# ✅ capabilities.drop: [ALL]
# ✅ volumes: 只允許特定類型

# ── 為 Namespace 設定 PSS ─────────────────────────────────
kubectl create namespace production

# 設定 restricted + warn（先觀察，再 enforce）
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest

# ── 符合 Restricted 的完整 Pod 設定 ──────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fully-restricted-pod
  namespace: production
spec:
  # Pod 層級安全設定
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534        # nobody 使用者（UID=65534）
    runAsGroup: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault

  # 只允許特定 Volume 類型（Restricted 不允許 hostPath）
  volumes:
  - name: tmp-vol
    emptyDir: {}

  containers:
  - name: app
    image: nginx:alpine

    # Container 層級安全設定
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]

    # Nginx 需要的可寫目錄
    volumeMounts:
    - name: tmp-vol
      mountPath: /tmp
    - name: tmp-vol
      mountPath: /var/cache/nginx
      subPath: cache
    - name: tmp-vol
      mountPath: /var/run
      subPath: run

    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF

# 測試不合規的 Pod 會被拒絕
cat <<'EOF' | kubectl apply -f - 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: production
spec:
  containers:
  - name: bad
    image: nginx  # 以 root 執行 → 違反 restricted
EOF
# 預期：Error ... violates PodSecurity "restricted:latest"
```

---

## Lab 12 OPA Gatekeeper 策略引擎

> 🔴 Hard｜考域 20%｜預估時間：20 分鐘

### OPA Gatekeeper 說明

```
OPA（Open Policy Agent）+ Gatekeeper = K8s 的動態 Admission Controller
使用 Rego 語言撰寫策略（Policy）
透過 ConstraintTemplate + Constraint 兩層結構定義規則
```

### 解題步驟

```bash
# ── 安裝 Gatekeeper ───────────────────────────────────────
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml

# 等待就緒
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system \
  --timeout=120s

# ── 建立 ConstraintTemplate（定義規則模板）────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels

      violation[{"msg": msg, "details": {"missing_labels": missing}}] {
        # 取得 Pod 的所有 labels
        provided := {label | input.review.object.metadata.labels[label]}
        # 取得要求的 labels
        required := {label | label := input.parameters.labels[_]}
        # 計算缺少的 labels
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Pod 缺少必要 labels：%v", [missing])
      }
EOF

# ── 建立 Constraint（套用策略到特定資源）─────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-labels
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - "production"        # 只在 production namespace 套用
  parameters:
    labels:
    - "app"               # 必須有 app label
    - "env"               # 必須有 env label
    - "version"           # 必須有 version label
EOF

# 等待 Constraint 生效
sleep 30

# ── 測試：缺少 label 被拒絕 ───────────────────────────────
kubectl apply -f - <<'EOF' 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: no-label-pod
  namespace: production
  # 缺少 app/env/version label
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF
# 預期：admission webhook denied → Pod 缺少必要 labels

# 有正確 label 可以建立
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: labeled-pod
  namespace: production
  labels:
    app: myapp
    env: production
    version: "1.0"
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

# ── 建立禁止 privileged 容器的策略 ───────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8snoprivileged
spec:
  crd:
    spec:
      names:
        kind: K8sNoPrivileged
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8snoprivileged
      violation[{"msg": msg}] {
        c := input.review.object.spec.containers[_]
        c.securityContext.privileged == true
        msg := sprintf("容器 %v 不允許以 privileged 模式運行", [c.name])
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sNoPrivileged
metadata:
  name: no-privileged-containers
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
EOF
```

---

## Lab 13 Secret 安全管理

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

```bash
# ── 問題：Secret 預設只是 base64（非加密）────────────────
kubectl create secret generic my-secret \
  --from-literal=api-key=SuperSecret123

# base64 解碼 = 明文（沒有真正加密）
kubectl get secret my-secret -o jsonpath='{.data.api-key}' | base64 -d
# 輸出：SuperSecret123

# ── 最佳實踐 1：最小化 Secret 存取 ───────────────────────
# 只允許特定 SA 讀取特定 Secret
kubectl create role secret-reader \
  --verb=get \
  --resource=secrets \
  --resource-name=my-secret  # 只能讀這一個 Secret！
  --namespace=default

kubectl create rolebinding secret-reader-binding \
  --role=secret-reader \
  --serviceaccount=default:my-app-sa \
  --namespace=default

# ── 最佳實踐 2：以 Volume 掛載（避免 env var 暴露）────────
# 環境變數問題：在 /proc/<pid>/environ 可被其他程序讀取
# Volume 掛載更安全，可設定 readOnly 和 defaultMode

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  volumes:
  - name: secret-vol
    secret:
      secretName: my-secret
      defaultMode: 0400   # 只有 owner 可讀（400 = r--------）
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "cat /secrets/api-key && sleep 3600"]
    volumeMounts:
    - name: secret-vol
      mountPath: /secrets
      readOnly: true
EOF

# ── 最佳實踐 3：Secret 存取稽核 ──────────────────────────
# 確保 Audit Log 記錄 Secret 的 get 操作
# （在 Audit Policy 中設定，見 Lab 20）

# ── 最佳實踐 4：etcd 加密（見 Lab 06）───────────────────

# ── 查找可能洩漏的 Secret ─────────────────────────────────
# 找出以環境變數方式使用 Secret 的 Pod（高風險）
kubectl get pods -A -o json | \
  jq '.items[] | 
    select(.spec.containers[].env[]?.valueFrom.secretKeyRef != null) |
    {
      pod: .metadata.name,
      ns: .metadata.namespace
    }'
```

---

## Lab 14 mTLS 服務間加密

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

```bash
# ── mTLS 概念 ────────────────────────────────────────────
# 傳統 TLS：只有 Server 驗證身份
# mTLS（Mutual TLS）：Client 和 Server 互相驗證
# 在 K8s 中：Service Mesh（Istio/Linkerd）自動處理 mTLS

# ── 手動建立 mTLS（基礎概念）────────────────────────────
# Step 1：建立 CA
openssl genrsa -out /tmp/ca.key 4096
openssl req -new -x509 -days 365 -key /tmp/ca.key \
  -out /tmp/ca.crt -subj "/CN=MyCA"

# Step 2：建立 Server 憑證
openssl genrsa -out /tmp/server.key 2048
openssl req -new -key /tmp/server.key \
  -out /tmp/server.csr -subj "/CN=my-service.default.svc.cluster.local"
openssl x509 -req -days 365 -in /tmp/server.csr \
  -CA /tmp/ca.crt -CAkey /tmp/ca.key \
  -CAcreateserial -out /tmp/server.crt

# Step 3：建立 Client 憑證
openssl genrsa -out /tmp/client.key 2048
openssl req -new -key /tmp/client.key \
  -out /tmp/client.csr -subj "/CN=client-app"
openssl x509 -req -days 365 -in /tmp/client.csr \
  -CA /tmp/ca.crt -CAkey /tmp/ca.key \
  -CAcreateserial -out /tmp/client.crt

# Step 4：建立 K8s Secrets
kubectl create secret generic mtls-server-certs \
  --from-file=tls.crt=/tmp/server.crt \
  --from-file=tls.key=/tmp/server.key \
  --from-file=ca.crt=/tmp/ca.crt

kubectl create secret generic mtls-client-certs \
  --from-file=tls.crt=/tmp/client.crt \
  --from-file=tls.key=/tmp/client.key \
  --from-file=ca.crt=/tmp/ca.crt

# ── 模擬 Istio 方式的 mTLS（概念展示）────────────────────
# 生產環境：使用 Istio 的 PeerAuthentication
cat <<'EOF' | cat  # 僅展示，不執行（需要 Istio 安裝）
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT   # 強制 mTLS（拒絕明文連線）
EOF
```

---

# Domain 5：供應鏈安全

---

## Lab 15 容器映像掃描：Trivy

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

```bash
# ── 安裝 Trivy ────────────────────────────────────────────
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin v0.48.0

trivy --version

# ── 掃描映像漏洞 ──────────────────────────────────────────
# 掃描特定映像（報告所有漏洞）
trivy image nginx:latest

# 只顯示高危和嚴重漏洞
trivy image --severity HIGH,CRITICAL nginx:latest

# 掃描並輸出 JSON（用於 CI/CD 整合）
trivy image --format json --output /tmp/nginx-scan.json nginx:latest

# 設定失敗條件（有 CRITICAL 漏洞就失敗，適用 CI/CD）
trivy image --exit-code 1 --severity CRITICAL nginx:latest
echo "Exit code: $?"  # 1 = 發現 CRITICAL 漏洞

# ── 掃描結果分析 ──────────────────────────────────────────
# 比較安全的映像
trivy image nginx:alpine         # alpine 基礎，漏洞更少
trivy image nginx:1.25-alpine

# 掃描本機掃描（Dockerfile 靜態分析）
trivy config ./Dockerfile

# ── 掃描 K8s 叢集中的映像 ────────────────────────────────
# 掃描叢集所有在跑的映像
trivy kubernetes --report summary cluster

# 掃描特定 namespace
trivy kubernetes --namespace production --report summary cluster

# ── 在 CI/CD 中整合（概念）──────────────────────────────
cat <<'PIPELINE'
# .gitlab-ci.yml 或 GitHub Actions 示例
scan-image:
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity CRITICAL ${IMAGE_NAME}
  allow_failure: false   # CRITICAL 漏洞會 block pipeline
PIPELINE
```

---

## Lab 16 映像簽名與驗證

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

```bash
# ── 安裝 cosign（Sigstore 映像簽名工具）─────────────────
curl -fsSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
  -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign

# ── 產生簽名金鑰對 ───────────────────────────────────────
cosign generate-key-pair

# 產生 cosign.key（私鑰）和 cosign.pub（公鑰）
ls -la cosign.*

# ── 簽名映像（需要有 registry 存取權）───────────────────
# 簽名本地映像並推送簽名到 registry
cosign sign --key cosign.key \
  registry.example.com/myapp:v1.0

# ── 驗證映像簽名 ─────────────────────────────────────────
cosign verify --key cosign.pub \
  registry.example.com/myapp:v1.0

# ── 查看映像的 SBOM（軟體物料清單）──────────────────────
# 生成 SBOM
trivy image --format cyclonedx \
  --output /tmp/sbom.json nginx:alpine

# 附加 SBOM 到映像
cosign attest --key cosign.key \
  --predicate /tmp/sbom.json \
  --type cyclonedx \
  registry.example.com/myapp:v1.0

# ── 在 K8s 中驗證（使用 Connaisseur）────────────────────
# Connaisseur 是 K8s Admission Controller，強制要求映像必須有簽名
# 生產環境：
# helm install connaisseur connaisseur/connaisseur \
#   --set validators[0].name=cosign \
#   --set validators[0].type=cosign \
#   --set validators[0].trustRoots[0].name=default \
#   --set validators[0].trustRoots[0].key="$(cat cosign.pub)"
```

---

## Lab 17 Admission Controller：ImagePolicyWebhook

> 🔴 Hard｜考域 20%｜預估時間：20 分鐘

```bash
# ── ImagePolicyWebhook 說明 ───────────────────────────────
# 當 Pod 建立時，API Server 呼叫外部 Webhook
# Webhook 決定是否允許該映像（可整合 Trivy/Anchore 等）

# ── Step 1：建立 Webhook 設定 ────────────────────────────
sudo mkdir -p /etc/kubernetes/admission

sudo cat > /etc/kubernetes/admission/image-policy-webhook.yaml <<'EOF'
imagePolicy:
  kubeConfigFile: /etc/kubernetes/admission/webhook-kubeconfig.yaml
  allowTTL: 50         # 允許結果快取時間（秒）
  denyTTL: 50          # 拒絕結果快取時間（秒）
  retryBackoff: 500    # Webhook 失敗重試間隔（毫秒）
  defaultAllow: false  # Webhook 不可達時：false = 拒絕所有（安全失效）
EOF

# ── Step 2：啟用 API Server Plugin ───────────────────────
# 在 kube-apiserver.yaml 加入：
# - --admission-control-config-file=/etc/kubernetes/admission/image-policy-webhook.yaml
# - --enable-admission-plugins=...,ImagePolicyWebhook

# ── Step 3：使用 ValidatingAdmissionWebhook（替代方案）──
# 更現代的方式：使用 ValidatingWebhookConfiguration
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: image-policy
webhooks:
- name: image-policy.example.com
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  clientConfig:
    service:
      name: image-policy-webhook
      namespace: default
      path: "/validate"
    caBundle: <base64-encoded-ca-cert>
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail  # Webhook 失敗時拒絕請求（安全失效）
  namespaceSelector:
    matchLabels:
      webhook: enabled
EOF

# ── 考試重點：常見 Admission Controller ──────────────────
# NamespaceLifecycle    → 防止刪除系統 namespace
# LimitRanger           → 套用 LimitRange 預設值
# ServiceAccount        → 自動掛載 SA token
# ResourceQuota         → 強制 ResourceQuota
# NodeRestriction       → 限制 kubelet 只能修改自己節點的物件
# PodSecurity           → 套用 Pod Security Standards
# ImagePolicyWebhook    → 外部映像政策（CKS 考點）
```

---

## Lab 18 安全的 Dockerfile 實踐

> 🟢 Easy｜考域 20%｜預估時間：10 分鐘

```dockerfile
# ── 安全 Dockerfile 範本（含詳細說明）─────────────────────

# ❌ 不安全的版本
# FROM ubuntu:latest          # latest tag 不可預測
# RUN apt-get install -y curl # 安裝不需要的工具
# COPY . .                    # 複製所有檔案（含敏感檔案）
# RUN npm install             # 包含 devDependencies
# CMD ["npm", "start"]        # 以 root 執行

# ✅ 安全的版本
# Stage 1：Build（包含 build 工具）
FROM node:20-alpine AS builder
WORKDIR /app

# 只複製 package 檔案（利用 Docker layer cache）
COPY package*.json ./
# 只安裝 production 依賴，避免 devDependencies
RUN npm ci --only=production --ignore-scripts
# ignore-scripts：防止 npm 執行惡意 postinstall 腳本

COPY src/ ./src/

# Stage 2：Runtime（最小映像）
FROM node:20-alpine AS runtime

# 安全：建立非 root 使用者
RUN addgroup -S appgroup -g 1001 && \
    adduser -S appuser -G appgroup -u 1001

# 設定工作目錄和權限
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app ./

# 切換到非 root 使用者
USER appuser

# 明確聲明 PORT（文件化目的）
EXPOSE 3000

# 健康檢查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node healthcheck.js || exit 1

# 使用 exec 格式（而非 shell 格式），確保信號正確傳遞
CMD ["node", "server.js"]
```

```bash
# ── Trivy Dockerfile 掃描 ─────────────────────────────────
trivy config Dockerfile

# ── .dockerignore（必要！）───────────────────────────────
cat > .dockerignore <<'EOF'
.git
.gitignore
.env
.env.*
*.md
node_modules
npm-debug.log
Dockerfile
.dockerignore
tests/
coverage/
.nyc_output/
*.test.js
secrets/
*.pem
*.key
*.crt
EOF
```

---

# Domain 6：監控、日誌與運行時安全

---

## Lab 19 Falco 異常行為偵測

> 🔴 Hard｜考域 20%｜預估時間：20 分鐘

### Falco 說明

```
Falco：CNCF 的開源雲端原生運行時安全工具
監控 K8s 和容器的系統呼叫（syscall）
即時偵測異常行為（如：容器內執行 shell、讀取敏感檔案）
```

### 解題步驟

```bash
# ── 安裝 Falco ────────────────────────────────────────────
# 在每個節點安裝（需要 kernel headers）
vagrant ssh k8s-node1

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
  https://download.falco.org/packages/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/falcosecurity.list

sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r) falco

# 啟動 Falco
sudo systemctl start falco
sudo systemctl enable falco

exit

# ── 或使用 Helm 安裝（CKS 考試常用方式）──────────────────
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set tty=true

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=falco \
  -n falco \
  --timeout=120s

# ── 理解 Falco 規則 ────────────────────────────────────────
# 預設規則：/etc/falco/falco_rules.yaml

# 關鍵規則示例：
cat <<'RULES'
# 偵測容器內執行 shell
- rule: Terminal shell in container
  desc: A shell was spawned by a non-shell program
  condition: >
    spawned_process
    and container
    and shell_procs
    and not proc.pname in (shell_binaries)
  output: >
    Shell spawned in a container (user=%user.name %container.info 
    shell=%proc.name parent=%proc.pname)
  priority: WARNING

# 偵測讀取敏感檔案
- rule: Read sensitive file untrusted
  desc: An attempt to read a sensitive file
  condition: >
    open_read
    and (fd.name startswith /etc/shadow
    or fd.name startswith /etc/passwd)
    and not trusted_containers
  output: >
    Sensitive file opened (user=%user.name file=%fd.name 
    container=%container.id)
  priority: ERROR
RULES

# ── 觸發 Falco 警告並觀察 ─────────────────────────────────
# 在容器內執行 shell（觸發 "Terminal shell in container"）
kubectl exec -n default $(kubectl get pod -o name | head -1) -- bash

# 讀取敏感檔案
kubectl exec $(kubectl get pod -o name | head -1) -- cat /etc/shadow

# 查看 Falco 日誌
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# ── 自定義 Falco 規則 ─────────────────────────────────────
cat <<'EOF' | kubectl create configmap custom-falco-rules --from-file=rules.yaml=/dev/stdin -n falco
- rule: Detect kubectl exec
  desc: Alert when kubectl exec is used
  condition: >
    k8s_audit
    and ka.verb=create
    and ka.target.resource=pods/exec
  output: >
    kubectl exec detected (user=%ka.user.name pod=%ka.target.name 
    ns=%ka.target.namespace)
  priority: WARNING
  source: k8s_audit
EOF
```

---

## Lab 20 Kubernetes Audit Log

> 🔴 Hard｜考域 20%｜預估時間：20 分鐘

### Audit Log 說明

```
Audit Log 記錄誰在何時對什麼資源做了什麼操作
四個階段（Stage）：
  RequestReceived  → API Server 收到請求
  ResponseStarted  → 回應 header 已傳送（streaming 請求）
  ResponseComplete → 回應已完整傳送
  Panic            → 發生 panic

四個 Audit Level：
  None    → 不記錄
  Metadata→ 記錄 metadata（誰/何時/什麼資源），不記錄 body
  Request → 記錄 metadata + 請求 body
  RequestResponse → 記錄 metadata + 請求 + 回應 body
```

### 解題步驟

```bash
vagrant ssh k8s-master

# ── Step 1：建立 Audit Policy ─────────────────────────────
sudo mkdir -p /etc/kubernetes/audit

sudo cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- "RequestReceived"   # 省略 RequestReceived 階段（減少日誌量）

rules:
# 記錄所有 Secret 操作（最高層級）
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]

# 記錄 Pod exec 操作（CKS 高關注）
- level: RequestResponse
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods/exec", "pods/portforward", "pods/proxy"]

# 記錄 ConfigMap 的寫操作
- level: Request
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["configmaps"]

# 記錄 RBAC 變更
- level: Request
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

# 記錄認證失敗（Metadata 層級即可）
- level: Metadata
  namespaces: ["kube-system"]

# 系統元件（kube-proxy 等）不記錄（減少噪音）
- level: None
  users:
  - "system:kube-proxy"
  - "system:node"
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services"]

# 其他所有請求記錄 Metadata
- level: Metadata
EOF

# ── Step 2：啟用 API Server Audit Log ────────────────────
# 備份
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /root/kube-apiserver-pre-audit.yaml.bak

# 加入參數到 kube-apiserver.yaml command 區塊：
# - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
# - --audit-log-path=/var/log/kubernetes/audit/audit.log
# - --audit-log-maxage=30
# - --audit-log-maxbackup=10
# - --audit-log-maxsize=100

# 加入 volumeMount：
# - mountPath: /etc/kubernetes/audit
#   name: audit-policy
#   readOnly: true
# - mountPath: /var/log/kubernetes/audit
#   name: audit-log

# 加入 volume：
# - hostPath:
#     path: /etc/kubernetes/audit
#     type: DirectoryOrCreate
#   name: audit-policy
# - hostPath:
#     path: /var/log/kubernetes/audit
#     type: DirectoryOrCreate
#   name: audit-log

sudo mkdir -p /var/log/kubernetes/audit

# ── Step 3：分析 Audit Log ────────────────────────────────
sleep 30  # 等待 API Server 重啟

# 產生一些操作
kubectl create secret generic audit-test --from-literal=key=value
kubectl delete secret audit-test

# 查看 audit log
sudo tail -20 /var/log/kubernetes/audit/audit.log | \
  python3 -m json.tool 2>/dev/null | head -60

# 過濾特定操作
sudo grep '"verb":"delete"' /var/log/kubernetes/audit/audit.log | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        print(f\"{e.get('stageTimestamp','')} {e.get('user',{}).get('username','')} {e.get('verb','')} {e.get('objectRef',{}).get('resource','')} {e.get('objectRef',{}).get('name','')}\")
    except:
        pass
"

# 找出存取 secrets 的操作
sudo grep '"secrets"' /var/log/kubernetes/audit/audit.log | wc -l
```

---

## Lab 21 運行時異常事件調查

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

```bash
# ── 調查 Pod 異常行為 ─────────────────────────────────────

# 情境：某個 Pod 疑似被入侵，正在做異常操作

# Step 1：識別可疑 Pod
kubectl get pods -A --sort-by='.metadata.creationTimestamp'
kubectl get events -A --sort-by='.lastTimestamp' | grep Warning

# Step 2：檢查 Pod 的安全設定
kubectl get pod <suspicious-pod> -o yaml | \
  grep -A 20 "securityContext"

# Step 3：查看 Pod 的網路連線（若 Pod 在運行）
kubectl exec <suspicious-pod> -- netstat -tulpn 2>/dev/null || \
kubectl exec <suspicious-pod> -- ss -tulpn

# Step 4：查看 Pod 的行程
kubectl exec <suspicious-pod> -- ps aux

# Step 5：查看 Pod 的環境變數（可能含敏感資訊）
kubectl exec <suspicious-pod> -- env

# Step 6：查看掛載的 Volume
kubectl exec <suspicious-pod> -- mount | grep -v "proc\|sys\|cgroup"

# Step 7：從 Audit Log 追查誰在何時存取了這個 Pod
sudo grep "suspicious-pod" /var/log/kubernetes/audit/audit.log | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        user = e.get('user', {}).get('username', 'unknown')
        verb = e.get('verb', '')
        resource = e.get('objectRef', {}).get('resource', '')
        ts = e.get('stageTimestamp', '')
        print(f'{ts} user={user} verb={verb} resource={resource}')
    except:
        pass
"

# Step 8：隔離可疑 Pod（立即封鎖網路）
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-suspicious-pod
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: suspicious-app   # 修改為實際的 label
  policyTypes:
  - Ingress
  - Egress
  # 空的 ingress/egress = 拒絕所有流量
EOF

# Step 9：保留證據後刪除
kubectl get pod <suspicious-pod> -o yaml > /tmp/forensics-pod.yaml
kubectl logs <suspicious-pod> > /tmp/forensics-logs.txt
kubectl delete pod <suspicious-pod>
```

---

# CKS Mock Exam 01

> ⏱️ 限時 45 分鐘｜不可看提示

---

**Q1**（10 分）AppArmor  
在 k8s-node1 上建立 AppArmor profile `deny-write`，禁止任何寫入操作  
建立 Pod `apparmor-nginx`，在 node1 上執行，套用此 profile

---

**Q2**（10 分）etcd 加密  
啟用 etcd Secret 靜態加密：
- 使用 AES-CBC 演算法
- 金鑰儲存在 `/etc/kubernetes/encryption/enc.yaml`
- 驗證已有 Secret 被重新加密（在 etcd 中看到 `k8s:enc:aescbc`）

---

**Q3**（8 分）RBAC 最小權限  
找出叢集中所有擁有 cluster-admin 的 ServiceAccount  
移除不應有此權限的 SA，改授予只能 get/list pods 的最小權限

---

**Q4**（12 分）Trivy + PSS  
1. 用 Trivy 掃描 `nginx:latest`，找出所有 CRITICAL 漏洞
2. 改用 `nginx:alpine`，確認漏洞減少
3. 在 namespace `hardened` 設定 Pod Security Standards（restricted）
4. 在 `hardened` namespace 部署符合 restricted 的 Pod

---

**Q5**（10 分）Audit Policy  
設定 Audit Policy：
- Secret 的所有操作記錄 RequestResponse
- Pod exec 記錄 RequestResponse  
- kube-system namespace 其他操作記錄 Metadata
- 其他記錄 None

---

### CKS Mock Exam 01 解答

<details>
<summary>展開解答</summary>

```bash
# Q1：AppArmor
vagrant ssh k8s-node1

sudo cat > /etc/apparmor.d/deny-write <<'EOF'
#include <tunables/global>
profile deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  network inet tcp,
  network inet udp,
  deny /** w,   # 禁止所有寫入
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/deny-write
exit

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-nginx
  annotations:
    container.apparmor.security.beta.kubernetes.io/nginx: localhost/deny-write
spec:
  nodeName: k8s-node1
  containers:
  - name: nginx
    image: nginx:alpine
EOF

# Q2：etcd 加密（見 Lab 06 詳細步驟）
AES_KEY=$(head -c 32 /dev/urandom | base64)
sudo mkdir -p /etc/kubernetes/encryption
sudo cat > /etc/kubernetes/encryption/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: ["secrets"]
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: ${AES_KEY}
  - identity: {}
EOF
# 更新 kube-apiserver.yaml 加入 --encryption-provider-config 參數

# Q3：RBAC 審查
kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | 
    {name: .metadata.name, subjects: .subjects}'

# 刪除危險 binding
# kubectl delete clusterrolebinding <bad-binding>

# 改授予最小權限
kubectl create clusterrole minimal-pod-reader \
  --verb=get,list --resource=pods
kubectl create clusterrolebinding minimal-pod-reader-binding \
  --clusterrole=minimal-pod-reader \
  --serviceaccount=<ns>:<sa>

# Q4：Trivy + PSS
trivy image --severity CRITICAL nginx:latest
trivy image --severity CRITICAL nginx:alpine

kubectl create namespace hardened
kubectl label namespace hardened \
  pod-security.kubernetes.io/enforce=restricted

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: hardened
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
EOF

# Q5：Audit Policy（見 Lab 20 詳細步驟）
sudo cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
- level: RequestResponse
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods/exec"]
- level: Metadata
  namespaces: ["kube-system"]
- level: None
EOF
```

</details>

---

# CKS Mock Exam 02

> ⏱️ 限時 45 分鐘

**Q1**（10 分）Seccomp  
在 Pod `seccomp-demo` 套用 RuntimeDefault seccomp profile，同時：
- 以 user 1000 執行
- Drop ALL capabilities
- 禁止 privilege escalation
- 根目錄唯讀（/tmp 除外）

**Q2**（10 分）Falco  
安裝 Falco，建立自定義規則：偵測任何在 `production` namespace 的容器中執行 `sh` 或 `bash`，alert level 設為 WARNING

**Q3**（8 分）映像安全  
1. 使用 Trivy 找出 `redis:latest` 的 HIGH+CRITICAL 漏洞數量
2. 找到 CVE 最少的 redis tag（在 alpine 和 slim 中選擇）
3. 建立 Deployment 使用更安全的 redis 版本

**Q4**（12 分）OPA Gatekeeper  
安裝 Gatekeeper，建立策略：
- 禁止所有容器使用 `latest` tag
- 強制所有 Pod 設定 resource requests（cpu 和 memory）

**Q5**（10 分）綜合安全審查  
對以下 Pod 進行完整安全審查，列出所有問題並修復：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  hostNetwork: true      # 問題 1
  hostPID: true          # 問題 2
  containers:
  - name: app
    image: nginx:latest   # 問題 3
    securityContext:
      privileged: true    # 問題 4
      runAsUser: 0        # 問題 5
    # 無 resource limits  # 問題 6
```

---

### CKS Mock Exam 02 解答

<details>
<summary>展開解答</summary>

```bash
# Q1
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: tmp
    emptyDir: {}
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
EOF

# Q2：Falco 自定義規則
helm install falco falcosecurity/falco \
  -n falco --create-namespace

cat <<'EOF' > /tmp/custom-falco-rules.yaml
customRules:
  production-shell-detection.yaml: |-
    - rule: Shell Spawned in Production Container
      desc: Detect shell execution in production namespace containers
      condition: >
        spawned_process
        and container
        and k8s.ns.name = "production"
        and proc.name in (shell_binaries)
      output: >
        Shell spawned in production namespace container
        (user=%user.name container=%container.name ns=%k8s.ns.name
        cmd=%proc.cmdline)
      priority: WARNING
EOF

helm upgrade falco falcosecurity/falco \
  -n falco \
  -f /tmp/custom-falco-rules.yaml

# Q3
trivy image --severity HIGH,CRITICAL redis:latest 2>/dev/null | tail -5
trivy image --severity HIGH,CRITICAL redis:alpine 2>/dev/null | tail -5
# alpine 版本漏洞較少

kubectl create deployment secure-redis --image=redis:7-alpine

# Q4：OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml

cat <<'EOF' | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8snolatesttag
spec:
  crd:
    spec:
      names:
        kind: K8sNoLatestTag
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8snolatesttag
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        endswith(container.image, ":latest")
        msg := sprintf("Container %v 使用了 latest tag，請指定明確版本", [container.name])
      }
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not contains(container.image, ":")
        msg := sprintf("Container %v 未指定 tag", [container.name])
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sNoLatestTag
metadata:
  name: no-latest-tag
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
EOF

# Q5：修復所有問題
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  # hostNetwork: true    ← 移除問題 1
  # hostPID: true        ← 移除問題 2
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine   # 修復問題 3：指定版本
    securityContext:
      privileged: false         # 修復問題 4
      runAsUser: 1000           # 修復問題 5：非 root
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    resources:                  # 修復問題 6：加 resource limits
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF
```

</details>

---

## CKS 考試速查表

```
╔═══════════════════════════════════════════════════════════════╗
║                  CKS 攻擊面與防禦對照表                        ║
╠════════════════════╦══════════════════════════════════════════╣
║ 攻擊向量           ║ 防禦措施                                  ║
╠════════════════════╬══════════════════════════════════════════╣
║ 映像漏洞           ║ Trivy 掃描 + 固定版本 + alpine 基礎映像   ║
║ 惡意映像           ║ cosign 簽名 + ImagePolicyWebhook          ║
║ 容器逃逸           ║ seccomp + AppArmor + Drop ALL caps        ║
║ 提權               ║ runAsNonRoot + allowPrivilegeEscalation   ║
║ Secret 洩漏        ║ etcd 加密 + RBAC 最小權限 + Volume 掛載   ║
║ 橫向移動           ║ NetworkPolicy + mTLS + RBAC              ║
║ 持久化後門         ║ Falco 偵測 + Audit Log + PSS             ║
║ 供應鏈攻擊         ║ SBOM + 映像簽名 + Gatekeeper             ║
║ API Server 攻擊    ║ RBAC + 禁匿名 + Admission Controllers    ║
║ etcd 存取          ║ 加密 + 網路隔離 + 備份                    ║
╚════════════════════╩══════════════════════════════════════════╝

CKS 考試必背指令：
# AppArmor 載入   │ apparmor_parser -r /etc/apparmor.d/<profile>
# AppArmor 狀態   │ apparmor_status
# Seccomp 狀態    │ cat /proc/<pid>/status | grep Seccomp
# Trivy 掃描      │ trivy image --severity CRITICAL,HIGH <image>
# Falco 日誌      │ kubectl logs -n falco -l app=falco
# Audit Log       │ tail -f /var/log/kubernetes/audit/audit.log
# etcd 直讀       │ ETCDCTL_API=3 etcdctl get /registry/secrets/...
# PSS 設定        │ kubectl label ns <ns> pod-security.k8s.io/enforce=restricted
```

---

*CKS Practice Labs v1.0 | Kubernetes 1.29 | 涵蓋官方考綱全六域*  
*前置要求：CKA 認證（CKS 報名條件）*  
*推薦練習平台：[killer.sh](https://killer.sh) CKS 模擬考試*
