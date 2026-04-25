# CKAD 全題型實戰練習手冊
## Certified Kubernetes Application Developer

> **考試定位**：以「開發者視角」操作 K8s，著重在部署、設定、觀測應用程式  
> **考試時長**：2 小時｜**及格分數**：66%  
> **與 CKA 差異**：不考叢集安裝/升級，著重 App 生命週期管理

```
CKAD 考域分布（2024-2025）：
┌──────────────────────────────────────────────────┬──────┐
│ Application Design and Build                     │  20% │
│ Application Deployment                           │  20% │
│ Application Observability and Maintenance        │  15% │
│ Application Environment, Configuration & Security│  25% │
│ Services and Networking                          │  20% │
└──────────────────────────────────────────────────┴──────┘
```

---

## 目錄

### Domain 1：應用設計與建構（20%）
- [Lab 01 🟢 多容器 Pod 設計模式](#lab-01-多容器-pod-設計模式)
- [Lab 02 🟡 Init Container 進階](#lab-02-init-container-進階)
- [Lab 03 🟡 Job 與 CronJob 進階](#lab-03-job-與-cronjob-進階)
- [Lab 04 🟢 Dockerfile → K8s 部署全流程](#lab-04-dockerfile--k8s-部署全流程)

### Domain 2：應用部署（20%）
- [Lab 05 🟡 Deployment 策略：Rolling / Recreate / Canary](#lab-05-deployment-策略rolling--recreate--canary)
- [Lab 06 🟡 Helm 套件管理](#lab-06-helm-套件管理)
- [Lab 07 🟢 Kustomize 環境差異化](#lab-07-kustomize-環境差異化)

### Domain 3：應用可觀測性與維護（15%）
- [Lab 08 🟡 健康探針：Liveness / Readiness / Startup](#lab-08-健康探針liveness--readiness--startup)
- [Lab 09 🟢 容器 Log 與除錯技巧](#lab-09-容器-log-與除錯技巧)
- [Lab 10 🟡 Resource Requests/Limits 與 QoS](#lab-10-resource-requestslimits-與-qos)

### Domain 4：應用環境、設定與安全（25%）
- [Lab 11 🟢 ConfigMap 與 Secret 進階用法](#lab-11-configmap-與-secret-進階用法)
- [Lab 12 🟡 SecurityContext：Pod 與 Container 層級](#lab-12-securitycontext-pod-與-container-層級)
- [Lab 13 🟡 ServiceAccount 與 API 存取](#lab-13-serviceaccount-與-api-存取)
- [Lab 14 🔴 Pod Security Standards（PSS）](#lab-14-pod-security-standardspss)

### Domain 5：服務與網路（20%）
- [Lab 15 🟢 Service 與 DNS 深入](#lab-15-service-與-dns-深入)
- [Lab 16 🟡 Ingress 路由進階](#lab-16-ingress-路由進階)
- [Lab 17 🟡 NetworkPolicy 應用隔離](#lab-17-networkpolicy-應用隔離)

### 綜合模擬
- [Mock Exam 01：CKAD 45 分鐘模擬](#ckad-mock-exam-01)
- [Mock Exam 02：CKAD 45 分鐘模擬](#ckad-mock-exam-02)

---

# Domain 1：應用設計與建構

---

## Lab 01 多容器 Pod 設計模式

> 🟢 Easy｜考域 20%｜預估時間：15 分鐘  
> **考試頻率：高** — CKAD 核心概念

### 四種多容器模式說明

```
┌─────────────────────────────────────────────────────────────┐
│  Sidecar   │ 輔助主容器，共享資源（日誌代理、Service Mesh）  │
│  Init      │ 主容器啟動前的前置任務（資料準備、等待服務）    │
│  Ambassador│ 代理主容器的外部通訊（資料庫連線、API Gateway） │
│  Adapter   │ 轉換主容器的輸出格式（監控指標標準化）         │
└─────────────────────────────────────────────────────────────┘
```

### 練習題

**題目 1**：Sidecar 模式 — nginx + log-shipper 共享日誌 Volume

**題目 2**：Ambassador 模式 — 主應用透過 localhost 存取資料庫 proxy

**題目 3**：Adapter 模式 — 將應用的非標準格式 metrics 轉換為 Prometheus 格式

### 解題步驟

```bash
# ── 題目 1：Sidecar ───────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-logging
  labels:
    pattern: sidecar
spec:
  volumes:
  - name: log-volume
    emptyDir: {}

  containers:
  # 主容器：產生日誌
  - name: web-server
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: log-volume
      mountPath: /var/log/nginx

  # Sidecar：讀取並處理日誌（模擬 Fluentd/Filebeat）
  - name: log-shipper
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Log shipper started"
      while true; do
        if [ -f /logs/access.log ]; then
          echo "[SHIP] $(wc -l < /logs/access.log) lines in access.log"
        fi
        sleep 15
      done
    volumeMounts:
    - name: log-volume
      mountPath: /logs
    resources:
      limits:
        memory: "32Mi"
        cpu: "25m"
EOF

kubectl logs sidecar-logging -c log-shipper

# ── 題目 2：Ambassador ─────────────────────────────────────
# Ambassador 讓主容器只需連 localhost，由 ambassador 處理實際路由
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-pattern
  labels:
    pattern: ambassador
spec:
  containers:
  # 主應用：只知道連 localhost:6379
  - name: main-app
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "App connecting to redis via localhost:6379..."
        nc -z localhost 6379 && echo "Connected!" || echo "Not available"
        sleep 10
      done

  # Ambassador：代理 Redis 連線（實際指向正確的 Redis）
  - name: redis-ambassador
    image: haproxy:alpine
    # 實際場景：haproxy 設定會將 localhost:6379 → redis-service:6379
    # 此處簡化為 sleep 模擬
    command: ["sh", "-c", "echo 'Ambassador proxy running' && sleep 3600"]
    ports:
    - containerPort: 6379
EOF

# ── 題目 3：Adapter ───────────────────────────────────────
# Adapter 將非標準格式 metrics 轉換為 Prometheus 格式
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: adapter-pattern
  labels:
    pattern: adapter
spec:
  volumes:
  - name: metrics-vol
    emptyDir: {}

  containers:
  # 主應用：輸出自定義格式 metrics
  - name: legacy-app
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "requests=100,errors=5,latency=200ms" > /metrics/raw.txt
        sleep 10
      done
    volumeMounts:
    - name: metrics-vol
      mountPath: /metrics

  # Adapter：轉換為 Prometheus 格式
  - name: metrics-adapter
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        if [ -f /raw/raw.txt ]; then
          cat /raw/raw.txt | awk -F'[=,]' '{
            print "# HELP app_requests Total requests"
            print "# TYPE app_requests counter"
            print "app_requests_total " $2
            print "app_errors_total " $4
          }' > /metrics/prometheus.txt
          echo "Metrics converted at $(date)"
        fi
        sleep 10
      done
    volumeMounts:
    - name: metrics-vol
      mountPath: /raw
    - name: metrics-vol
      mountPath: /metrics
EOF

kubectl logs adapter-pattern -c metrics-adapter
```

---

## Lab 02 Init Container 進階

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

### 練習題

**題目 1**：使用 Init Container 等待資料庫服務就緒後才啟動主應用

**題目 2**：使用多個 Init Container 依序執行不同前置任務

### 解題步驟

```bash
# ── 題目 1：等待依賴服務 ──────────────────────────────────
# 先建立一個 Service（模擬資料庫）
kubectl create service clusterip mydb --tcp=5432:5432

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wait-for-db
spec:
  initContainers:
  # Init 1：等待 mydb service 的 DNS 解析成功
  - name: wait-for-db
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Waiting for database..."
      until nslookup mydb.default.svc.cluster.local; do
        echo "Database not ready, retrying in 5s..."
        sleep 5
      done
      echo "Database is ready!"

  # Init 2：執行資料庫 migration（模擬）
  - name: run-migration
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Running database migration..."
      sleep 3
      echo "Migration complete!"
      echo "v1.0.0" > /migration/version.txt
    volumeMounts:
    - name: migration-info
      mountPath: /migration

  containers:
  - name: web-app
    image: nginx:alpine
    volumeMounts:
    - name: migration-info
      mountPath: /app/migration
    readinessProbe:
      exec:
        command: ["test", "-f", "/app/migration/version.txt"]
      initialDelaySeconds: 2

  volumes:
  - name: migration-info
    emptyDir: {}
EOF

# 觀察 Init Container 執行順序
kubectl get pod wait-for-db -w
# Init:0/2 → Init:1/2 → PodInitializing → Running

kubectl logs wait-for-db -c wait-for-db
kubectl logs wait-for-db -c run-migration
```

---

## Lab 03 Job 與 CronJob 進階

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

### 練習題

**題目 1**：建立並行 Job（5 個任務，同時跑 3 個）

**題目 2**：建立 CronJob，並手動觸發，設定 deadline 與 concurrency policy

**題目 3**：偵測 Job 失敗並設定重試次數

### 解題步驟

```bash
# ── 題目 1：並行 Job ──────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 5         # 總共需要 5 個成功
  parallelism: 3         # 同時最多跑 3 個
  backoffLimit: 3        # 整體失敗重試上限
  activeDeadlineSeconds: 120  # 整個 Job 最多跑 2 分鐘
  template:
    spec:
      restartPolicy: Never  # Never = 失敗建新 Pod，OnFailure = 原 Pod 重啟
      containers:
      - name: worker
        image: busybox
        command:
        - sh
        - -c
        - |
          WORKER_ID=$(hostname | rev | cut -d'-' -f1 | rev)
          echo "Worker ${WORKER_ID} started at $(date)"
          sleep $((RANDOM % 10 + 5))
          echo "Worker ${WORKER_ID} finished"
EOF

# 觀察並行執行
watch kubectl get pods -l job-name=parallel-job

# ── 題目 2：CronJob 進階 ──────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-generator
spec:
  schedule: "*/2 * * * *"        # 每 2 分鐘
  startingDeadlineSeconds: 60    # 錯過排程後 60 秒內仍可執行
  concurrencyPolicy: Replace     # Allow/Forbid/Replace
  # Allow  = 允許並行（預設）
  # Forbid  = 跳過（前一個未完成就不執行）
  # Replace = 取消前一個，執行新的
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  suspend: false                 # true = 暫停 CronJob
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: reporter
            image: busybox
            command:
            - sh
            - -c
            - |
              echo "Report generated at $(date)"
              echo "Data: $(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
EOF

# 手動觸發 CronJob
kubectl create job manual-report --from=cronjob/report-generator

# 暫停 CronJob
kubectl patch cronjob report-generator -p '{"spec":{"suspend":true}}'

# 恢復
kubectl patch cronjob report-generator -p '{"spec":{"suspend":false}}'

# ── 題目 3：Job 失敗處理 ──────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: flaky-job
spec:
  backoffLimit: 4    # 最多重試 4 次
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox
        command:
        - sh
        - -c
        - |
          # 模擬 70% 成功率
          if [ $((RANDOM % 10)) -lt 7 ]; then
            echo "Success!"
            exit 0
          else
            echo "Failed!" >&2
            exit 1
          fi
EOF

kubectl get job flaky-job -w
kubectl describe job flaky-job | grep -A 5 "Events:"
```

---

## Lab 04 Dockerfile → K8s 部署全流程

> 🟢 Easy｜考域 20%｜預估時間：10 分鐘

```bash
# ── 撰寫 Dockerfile（最佳實踐）─────────────────────────────
mkdir -p /tmp/myapp && cd /tmp/myapp

cat > Dockerfile <<'EOF'
# 多階段建置（Multi-stage build）— 減小最終映像大小
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine AS runtime
# 安全最佳實踐：不以 root 執行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER appuser            # 切換非 root 使用者
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q -O- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
EOF

# ── 對應的 K8s Deployment 最佳實踐 ──────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
    version: "1.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: myapp
        version: "1.0"
    spec:
      # 安全：不以 root 執行
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000

      # 映像拉取策略
      imagePullPolicy: IfNotPresent

      containers:
      - name: myapp
        image: nginx:alpine   # 替代示意
        ports:
        - name: http
          containerPort: 80

        # 資源限制（必填的生產最佳實踐）
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"

        # 健康探針
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3

        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20

        # 環境變數（從 ConfigMap/Secret 注入）
        envFrom:
        - configMapRef:
            name: app-config
            optional: true

      # 優雅關閉
      terminationGracePeriodSeconds: 30

      # 反親和性：Pod 分散在不同節點
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: kubernetes.io/hostname
EOF
```

---

# Domain 2：應用部署

---

## Lab 05 Deployment 策略：Rolling / Recreate / Canary

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

### 練習題

**題目 1**：演示 RollingUpdate 策略的 maxSurge 和 maxUnavailable 行為

**題目 2**：使用 Recreate 策略（先全停再全起）

**題目 3**：手動實作 Canary 部署（10% 流量到新版本）

### 解題步驟

```bash
# ── 題目 1：RollingUpdate ─────────────────────────────────
kubectl create deployment rolling-demo --image=nginx:1.24 --replicas=6

# 設定 RollingUpdate 參數
kubectl patch deployment rolling-demo -p '{
  "spec": {
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxSurge": 2,
        "maxUnavailable": 1
      }
    }
  }
}'

# 更新 image 並觀察（另開終端機）
kubectl set image deployment/rolling-demo nginx=nginx:1.25
kubectl rollout status deployment/rolling-demo --watch

# 暫停更新（考試題：更新到一半，先暫停）
kubectl rollout pause deployment/rolling-demo
kubectl get pods   # 部分舊版、部分新版

# 繼續更新
kubectl rollout resume deployment/rolling-demo

# ── 題目 2：Recreate 策略 ─────────────────────────────────
# Recreate：先刪全部舊 Pod，再建新 Pod（有停機時間）
# 適用：不允許新舊版同時存在的有狀態應用
kubectl create deployment recreate-demo --image=nginx:1.24 --replicas=3
kubectl patch deployment recreate-demo -p '{"spec":{"strategy":{"type":"Recreate"}}}'

kubectl set image deployment/recreate-demo nginx=nginx:1.25
# 觀察：所有舊 Pod 先 Terminating，然後新 Pod 才 Creating

# ── 題目 3：Canary 部署（手動實作）──────────────────────────
# 原理：stable 和 canary 共用同一個 Service selector（app=myapp）
# 透過 Pod 數量控制流量比例

# 穩定版（90% 流量）
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-stable
spec:
  replicas: 9            # 9/(9+1) = 90% 流量
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp       # Service 透過這個 label 選取
        track: stable
        version: "1.0"
    spec:
      containers:
      - name: app
        image: nginx:1.24-alpine
        ports:
        - containerPort: 80
---
# Canary 版（10% 流量）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-canary
spec:
  replicas: 1            # 1/(9+1) = 10% 流量
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp       # 同一個 label，被同一個 Service 選取
        track: canary
        version: "2.0"
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine   # 新版本
        ports:
        - containerPort: 80
---
# Service：同時選取 stable 和 canary Pod
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
spec:
  selector:
    app: myapp           # 選取所有 app=myapp 的 Pod
  ports:
  - port: 80
    targetPort: 80
EOF

# 驗證：endpoints 包含兩個 Deployment 的 Pod
kubectl get endpoints myapp-svc

# Canary 驗收後，逐步遷移：
# 方法：增加 canary replicas，減少 stable replicas
kubectl scale deployment myapp-canary --replicas=5   # 50% 流量
kubectl scale deployment myapp-stable --replicas=5
# ... 最終全切到新版
kubectl scale deployment myapp-canary --replicas=10
kubectl scale deployment myapp-stable --replicas=0
```

---

## Lab 06 Helm 套件管理

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

```bash
# ── 安裝 Helm ─────────────────────────────────────────────
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ── 新增 Helm Repository ──────────────────────────────────
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo update

# 搜尋 Chart
helm search repo nginx
helm search repo bitnami/nginx --versions   # 列出所有版本

# ── 安裝 Chart ────────────────────────────────────────────
# 安裝 nginx（自訂 Values）
helm install my-nginx bitnami/nginx \
  --namespace helm-demo \
  --create-namespace \
  --set replicaCount=2 \
  --set service.type=NodePort \
  --version 15.0.0   # 鎖定版本（生產必要）

# 查看安裝狀態
helm list -n helm-demo
helm status my-nginx -n helm-demo

# 查看 Chart 可設定的 Values
helm show values bitnami/nginx | head -50

# ── 使用 values.yaml 安裝 ────────────────────────────────
cat > /tmp/my-values.yaml <<'EOF'
replicaCount: 3
service:
  type: NodePort
  nodePorts:
    http: "30090"
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
EOF

helm upgrade my-nginx bitnami/nginx \
  -n helm-demo \
  -f /tmp/my-values.yaml

# ── Helm 版本管理 ─────────────────────────────────────────
helm history my-nginx -n helm-demo    # 查看 Release 歷史
helm rollback my-nginx 1 -n helm-demo # 回滾到 revision 1

# ── 建立自定義 Chart ─────────────────────────────────────
helm create my-chart
tree my-chart/
# my-chart/
# ├── Chart.yaml          # Chart 元數據
# ├── values.yaml         # 預設值
# ├── templates/          # K8s manifest 模板
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   └── _helpers.tpl    # 共用 template 函數
# └── charts/             # 依賴 Chart

# Lint 和 Template 渲染預覽
helm lint my-chart/
helm template my-chart/ --values my-chart/values.yaml

# 打包
helm package my-chart/

# 清理
helm uninstall my-nginx -n helm-demo
```

---

## Lab 07 Kustomize 環境差異化

> 🟢 Easy｜考域 20%｜預估時間：12 分鐘

```bash
# Kustomize 讓你用 overlay 管理 dev/staging/prod 差異
# K8s 1.14+ 內建（kubectl apply -k）

mkdir -p /tmp/kustomize-demo/{base,overlays/{dev,prod}}

# ── Base：共用基礎設定 ────────────────────────────────────
cat > /tmp/kustomize-demo/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

cat > /tmp/kustomize-demo/base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
EOF

cat > /tmp/kustomize-demo/base/kustomization.yaml <<'EOF'
resources:
- deployment.yaml
- service.yaml
EOF

# ── Dev Overlay：開發環境差異 ─────────────────────────────
cat > /tmp/kustomize-demo/overlays/dev/kustomization.yaml <<'EOF'
namePrefix: dev-            # 所有資源加前綴
commonLabels:
  env: development

resources:
- ../../base

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 1              # dev 只跑 1 個
  target:
    kind: Deployment
    name: web-app

images:
- name: nginx
  newTag: "1.24-alpine"    # dev 用舊版測試
EOF

# ── Prod Overlay：生產環境差異 ────────────────────────────
cat > /tmp/kustomize-demo/overlays/prod/kustomization.yaml <<'EOF'
namePrefix: prod-
commonLabels:
  env: production

resources:
- ../../base

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 5              # prod 跑 5 個
    - op: add
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          memory: "128Mi"
          cpu: "200m"
        limits:
          memory: "256Mi"
          cpu: "500m"
  target:
    kind: Deployment
    name: web-app

images:
- name: nginx
  newTag: "1.25-alpine"    # prod 用最新穩定版
EOF

# ── 使用 Kustomize ────────────────────────────────────────
# 預覽 dev 環境
kubectl kustomize /tmp/kustomize-demo/overlays/dev

# 套用 dev 環境
kubectl apply -k /tmp/kustomize-demo/overlays/dev

# 套用 prod 環境
kubectl apply -k /tmp/kustomize-demo/overlays/prod

# 查看差異
kubectl get deploy -l env=development
kubectl get deploy -l env=production
```

---

# Domain 3：應用可觀測性與維護

---

## Lab 08 健康探針：Liveness / Readiness / Startup

> 🟡 Medium｜考域 15%｜預估時間：15 分鐘

### 三種探針說明

```
┌───────────────┬──────────────────────────────────────────────┐
│ startupProbe  │ 首次啟動探測（啟動時間長的應用）              │
│               │ 成功前，liveness/readiness 暫停              │
│               │ 失敗則重啟 container                         │
├───────────────┼──────────────────────────────────────────────┤
│ livenessProbe │ 持續存活檢查                                 │
│               │ 失敗則重啟 container（解決 deadlock）         │
├───────────────┼──────────────────────────────────────────────┤
│ readinessProbe│ 就緒檢查（能否接受流量）                     │
│               │ 失敗則從 Service Endpoints 移除               │
│               │ 不重啟 container！                           │
└───────────────┴──────────────────────────────────────────────┘
```

### 練習題

**題目 1**：三種探針類型：httpGet、tcpSocket、exec

**題目 2**：模擬 readinessProbe 失敗，觀察 Endpoints 變化

### 解題步驟

```bash
# ── 題目 1：三種探針實作 ──────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe-demo
spec:
  containers:
  - name: web
    image: nginx:alpine
    ports:
    - containerPort: 80

    # Startup Probe：應用啟動期間使用
    # 允許最多 30*10=300 秒啟動時間
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 30
      periodSeconds: 10

    # Liveness Probe：持續監控應用是否存活
    livenessProbe:
      httpGet:           # 方式 1：HTTP GET
        path: /
        port: 80
        httpHeaders:
        - name: X-Probe
          value: liveness
      initialDelaySeconds: 15   # 首次探測前等待
      periodSeconds: 20          # 探測間隔
      timeoutSeconds: 3          # 超時時間
      failureThreshold: 3        # 連續失敗幾次才重啟

    # Readiness Probe：是否可接受流量
    readinessProbe:
      tcpSocket:         # 方式 2：TCP Socket 連線測試
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      successThreshold: 1        # 連續成功幾次才算就緒
      failureThreshold: 3
EOF

# ── Exec 探針示例 ─────────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: exec-probe
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "touch /tmp/healthy && sleep 30 && rm /tmp/healthy && sleep 600"]
    livenessProbe:
      exec:              # 方式 3：執行命令（exit 0 = 健康）
        command:
        - test
        - -f
        - /tmp/healthy   # 檔案存在則健康，30 秒後被刪除
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 2
EOF

kubectl get pod exec-probe -w
# 30 秒後 /tmp/healthy 被刪 → probe 失敗 → 自動重啟

# ── 題目 2：readinessProbe 失敗觀察 ───────────────────────
kubectl create deployment ready-demo --image=nginx --replicas=3
kubectl expose deployment ready-demo --port=80

# 查看初始 endpoints
kubectl get endpoints ready-demo

# 在某個 Pod 中製造 readiness 失敗（刪掉 nginx 設定）
POD=$(kubectl get pods -l app=ready-demo -o name | head -1)
kubectl exec ${POD} -- rm /etc/nginx/nginx.conf

# 觀察：該 Pod 從 Endpoints 移除，但不重啟（liveness 仍正常）
kubectl get endpoints ready-demo -w
kubectl describe ${POD} | grep -A 10 "Conditions"
```

---

## Lab 09 容器 Log 與除錯技巧

> 🟢 Easy｜考域 15%｜預估時間：10 分鐘

```bash
# ── 基本 Log 操作 ─────────────────────────────────────────
kubectl logs <pod-name>
kubectl logs <pod-name> --previous           # 崩潰前的日誌
kubectl logs <pod-name> -f                   # 即時追蹤
kubectl logs <pod-name> --since=1h           # 最近一小時
kubectl logs <pod-name> --timestamps         # 顯示時間戳
kubectl logs <pod-name> -c <container>       # 多容器

# ── 進入 Pod 除錯 ─────────────────────────────────────────
kubectl exec -it <pod-name> -- bash
kubectl exec -it <pod-name> -- sh            # 若無 bash
kubectl exec -it <pod-name> -c <container> -- bash

# ── ephemeral debug container（K8s 1.23+）─────────────────
# 為已在運行的 Pod 注入除錯工具容器（不重啟 Pod）
kubectl debug -it <pod-name> \
  --image=busybox \
  --target=<container-name>   # 共享目標容器的 process namespace

# 建立 debug Pod（複製現有 Pod 設定）
kubectl debug <pod-name> \
  -it \
  --copy-to=debug-pod \
  --image=busybox \
  --set-image=<container-name>=busybox

# ── 常用除錯工具 Pod ───────────────────────────────────────
# 快速建立功能完整的除錯 Pod
kubectl run debug-pod \
  --image=nicolaka/netshoot \   # 包含 curl, dig, nmap, tcpdump 等
  --restart=Never \
  -it \
  --rm \                        # 退出後自動刪除
  -- bash

# ── 複製 Pod 並修改 command（除錯 crashloop）────────────────
# CrashLoopBackOff 的 Pod 無法 exec，用這個方法：
kubectl debug <crashloop-pod> \
  -it \
  --copy-to=debug-copy \
  --set-image=<container>=busybox \
  -- sh
# 現在可以手動執行原本的指令，觀察錯誤
```

---

## Lab 10 Resource Requests/Limits 與 QoS

> 🟡 Medium｜考域 15%｜預估時間：12 分鐘

### QoS 三個等級

```
┌────────────────┬──────────────────────────────────────────────┐
│ Guaranteed     │ requests == limits（CPU 和 Memory 都設）      │
│                │ 最高優先，最後被驅逐                          │
├────────────────┼──────────────────────────────────────────────┤
│ Burstable      │ requests < limits，或只有部分設定             │
│                │ 中等優先                                      │
├────────────────┼──────────────────────────────────────────────┤
│ BestEffort     │ 完全未設 requests 和 limits                   │
│                │ 最低優先，最先被驅逐（節點資源不足時）         │
└────────────────┴──────────────────────────────────────────────┘
```

```bash
# ── Guaranteed QoS ────────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "200m"
      limits:
        memory: "128Mi"   # requests == limits → Guaranteed
        cpu: "200m"
EOF

kubectl get pod guaranteed-pod -o jsonpath='{.status.qosClass}'
# 輸出：Guaranteed

# ── Burstable QoS ─────────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"   # limits > requests → Burstable
        cpu: "500m"
EOF

# ── LimitRange：設定 Namespace 預設值 ────────────────────
# 若 Pod 未設定 resources，自動套用 LimitRange 的預設值
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: default
spec:
  limits:
  - type: Container
    default:            # 預設 limits
      cpu: "200m"
      memory: "128Mi"
    defaultRequest:     # 預設 requests
      cpu: "100m"
      memory: "64Mi"
    max:                # 最大允許值
      cpu: "2"
      memory: "2Gi"
    min:                # 最小要求值
      cpu: "50m"
      memory: "32Mi"
EOF

# ── ResourceQuota：限制 Namespace 總用量 ─────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: default
spec:
  hard:
    pods: "20"                    # 最多 20 個 Pod
    requests.cpu: "4"             # CPU requests 總量
    requests.memory: "4Gi"        # Memory requests 總量
    limits.cpu: "8"               # CPU limits 總量
    limits.memory: "8Gi"          # Memory limits 總量
    persistentvolumeclaims: "5"   # 最多 5 個 PVC
EOF

kubectl describe resourcequota namespace-quota
```

---

# Domain 4：應用環境、設定與安全

---

## Lab 11 ConfigMap 與 Secret 進階用法

> 🟢 Easy｜考域 25%｜預估時間：12 分鐘

```bash
# ── ConfigMap：從多種來源建立 ────────────────────────────
# 從字面值
kubectl create configmap app-cm \
  --from-literal=ENV=prod \
  --from-literal=LOG=info

# 從檔案（key = 檔名）
echo "server { listen 80; }" > /tmp/nginx.conf
kubectl create configmap nginx-cm --from-file=/tmp/nginx.conf

# 從目錄（目錄內每個檔案成為一個 key）
mkdir /tmp/configs
echo "db1" > /tmp/configs/primary.conf
echo "db2" > /tmp/configs/replica.conf
kubectl create configmap db-cm --from-file=/tmp/configs/

# ── Secret 類型 ───────────────────────────────────────────
# generic（通用）
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='P@ssw0rd!'

# docker-registry（映像拉取憑證）
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=user@example.com

# tls（TLS 憑證）
kubectl create secret tls tls-secret \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key

# ── 四種注入方式綜合示範 ──────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-demo
spec:
  volumes:
  - name: cm-vol
    configMap:
      name: nginx-cm
      items:               # 選擇性掛載特定 key
      - key: nginx.conf
        path: nginx.conf   # 掛載後的檔名
  - name: secret-vol
    secret:
      secretName: db-creds
      defaultMode: 0400    # 設定檔案權限（只有 owner 可讀）

  imagePullSecrets:
  - name: regcred          # 使用 docker-registry secret

  containers:
  - name: app
    image: nginx:alpine

    # 方式 1：整個 ConfigMap 注入為環境變數
    envFrom:
    - configMapRef:
        name: app-cm

    # 方式 2：Secret 特定 key 注入
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: password

    # 方式 3：Volume 掛載（ConfigMap 檔案）
    volumeMounts:
    - name: cm-vol
      mountPath: /etc/nginx/conf.d
      readOnly: true

    # 方式 4：Volume 掛載（Secret 檔案）
    - name: secret-vol
      mountPath: /run/secrets
      readOnly: true
EOF

# 驗證
kubectl exec config-demo -- env | grep -E "ENV|LOG|DB_"
kubectl exec config-demo -- ls /etc/nginx/conf.d/
kubectl exec config-demo -- ls -la /run/secrets/
```

---

## Lab 12 SecurityContext：Pod 與 Container 層級

> 🟡 Medium｜考域 25%｜預估時間：15 分鐘

```bash
# ── Pod 層級 SecurityContext ──────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: security-demo
spec:
  # Pod 層級：影響所有容器
  securityContext:
    runAsUser: 1000             # 以 UID 1000 執行
    runAsGroup: 3000            # 以 GID 3000 執行
    fsGroup: 2000               # Volume 的 GID（讓容器可讀寫）
    runAsNonRoot: true          # 禁止以 root 執行
    seccompProfile:
      type: RuntimeDefault      # 使用 runtime 預設 seccomp profile

  volumes:
  - name: data
    emptyDir: {}

  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "id && ls -la /data && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data

    # Container 層級：覆蓋 Pod 層級設定
    securityContext:
      allowPrivilegeEscalation: false   # 禁止提權（sudo 等）
      readOnlyRootFilesystem: true      # 根目錄唯讀（防止寫入惡意檔案）
      capabilities:
        drop:
        - ALL             # 刪除所有 Linux capabilities
        add:
        - NET_BIND_SERVICE # 只加回需要的（綁定 1024 以下 port）
EOF

kubectl exec security-demo -- id
# 預期：uid=1000 gid=3000 groups=2000

kubectl exec security-demo -- touch /test 2>&1
# 預期：Read-only file system

# ── 驗證 privilege escalation 被禁止 ──────────────────────
kubectl exec security-demo -- sh -c "su root" 2>&1
# 預期：Permission denied 或 su: must be suid to work properly
```

---

## Lab 13 ServiceAccount 與 API 存取

> 🟡 Medium｜考域 25%｜預估時間：15 分鐘

```bash
# ── ServiceAccount Token 機制 ─────────────────────────────
# K8s 1.24+ 預設不自動建立 SA Token Secret
# Pod 使用 Projected Volume 取得有時效的 token

kubectl create serviceaccount my-app-sa

# 查看 SA
kubectl describe serviceaccount my-app-sa

# 手動建立長效 Token（不建議生產使用）
kubectl create token my-app-sa --duration=24h

# ── Pod 使用 ServiceAccount ───────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sa-demo
spec:
  serviceAccountName: my-app-sa    # 指定 SA
  automountServiceAccountToken: true  # 自動掛載 token

  containers:
  - name: app
    image: curlimages/curl
    command:
    - sh
    - -c
    - |
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

      echo "=== Token 前 50 字元 ==="
      echo ${TOKEN:0:50}

      echo "=== 嘗試呼叫 API Server ==="
      curl -s --cacert $CACERT \
        -H "Authorization: Bearer $TOKEN" \
        https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/pods \
        | head -20
    sleep 3600
EOF

# 若 SA 無 RBAC 權限，API 回傳 403 Forbidden
kubectl logs sa-demo

# 為 SA 授權後再測試
kubectl create rolebinding sa-pod-reader \
  --clusterrole=view \
  --serviceaccount=default:my-app-sa \
  --namespace=default

# ── 禁止自動掛載 Token（安全最佳實踐）───────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
spec:
  automountServiceAccountToken: false   # 不掛載 token
  containers:
  - name: app
    image: nginx:alpine
EOF
```

---

## Lab 14 Pod Security Standards（PSS）

> 🔴 Hard｜考域 25%｜預估時間：15 分鐘

### PSS 三個等級

```
Privileged  → 完全無限制（不建議生產使用）
Baseline    → 防止已知特權提升（最低安全要求）
Restricted  → 嚴格限制（生產推薦）
```

```bash
# PSS 透過 Namespace label 啟用
# 有三種動作模式：enforce（拒絕）、warn（警告）、audit（記錄）

# ── 設定 Namespace PSS ────────────────────────────────────
kubectl create namespace pss-demo

kubectl label namespace pss-demo \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.29 \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted

# 嘗試部署不符合 restricted 的 Pod（應被拒絕）
cat <<'EOF' | kubectl apply -f - 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: pss-demo
spec:
  containers:
  - name: app
    image: nginx       # 以 root 執行 → violated restricted
EOF
# 預期輸出：Error ... violates PodSecurity

# 符合 restricted 的 Pod
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: pss-demo
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
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-cache
      mountPath: /var/cache/nginx
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}
  - name: var-run
    emptyDir: {}
EOF

kubectl get pod secure-pod -n pss-demo
```

---

# Domain 5：服務與網路

---

## Lab 15 Service 與 DNS 深入

> 🟢 Easy｜考域 20%｜預估時間：10 分鐘

```bash
# ── K8s DNS 格式 ──────────────────────────────────────────
# Service:  <svc>.<ns>.svc.<cluster-domain>
# Pod:      <pod-ip-dash>.<ns>.pod.<cluster-domain>
# 範例：
# nginx.default.svc.cluster.local
# 10-244-1-5.default.pod.cluster.local

# ── Headless Service（無 ClusterIP）──────────────────────
# 用於 StatefulSet，DNS 直接解析到 Pod IP
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
spec:
  clusterIP: None       # Headless：不分配 ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
EOF

# 用 DNS 測試 Headless Service
kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
  nslookup headless-svc.default.svc.cluster.local
# 回傳多個 A record（每個 Pod 一個），而非單一 ClusterIP

# ── Service 不帶 selector（外部服務代理）─────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-postgres
spec:
  ports:
  - port: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-postgres   # 名稱必須與 Service 相同
subsets:
- addresses:
  - ip: 192.168.1.100       # 外部資料庫 IP
  ports:
  - port: 5432
EOF
# 叢集內 Pod 透過 external-postgres:5432 連外部 DB

# ── 驗證 Service DNS ──────────────────────────────────────
kubectl run test --image=busybox --rm -it --restart=Never -- sh
# 在 Pod 內：
# nslookup kubernetes.default
# wget -qO- http://<service-name>.<namespace>
# exit
```

---

## Lab 16 Ingress 路由進階

> 🟡 Medium｜考域 20%｜預估時間：15 分鐘

```bash
# ── 路徑類型說明 ──────────────────────────────────────────
# Exact   → 完全比對（/foo 只匹配 /foo）
# Prefix  → 前綴比對（/foo 匹配 /foo、/foobar、/foo/bar）
# ImplementationSpecific → 由 IngressClass 決定

# ── 多 Host 路由 ─────────────────────────────────────────
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  # Host 1：API 服務
  - host: api.myapp.local
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1-svc
            port:
              number: 8080
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2-svc
            port:
              number: 8080

  # Host 2：Web 前端
  - host: www.myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
EOF

# ── TLS 終止（HTTPS）────────────────────────────────────
# 建立自簽憑證
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=myapp.local"

kubectl create secret tls myapp-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls      # 引用 TLS secret
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
EOF
```

---

## Lab 17 NetworkPolicy 應用隔離

> 🟡 Medium｜考域 20%｜預估時間：12 分鐘

```bash
# ── 三層網路隔離：frontend → backend → database ────────────
kubectl create namespace app-ns

# 建立三層應用
kubectl run frontend -n app-ns --image=nginx --labels="tier=frontend"
kubectl run backend  -n app-ns --image=nginx --labels="tier=backend"
kubectl run database -n app-ns --image=nginx --labels="tier=database"

# 策略：
# frontend → backend  ✅ 允許
# backend  → database ✅ 允許
# frontend → database ❌ 禁止
# 其他 → 所有        ❌ 禁止

cat <<'EOF' | kubectl apply -f -
# 1. 預設拒絕所有
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# 2. backend 允許 frontend 進入
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
---
# 3. database 允許 backend 進入
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
---
# 4. 允許 DNS Egress（所有 Pod 都需要）
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: app-ns
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
---
# 5. frontend 允許 egress 到 backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes: [Egress]
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
---
# 6. backend 允許 egress 到 database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes: [Egress]
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
EOF

# 驗證
BACKEND_IP=$(kubectl get pod backend -n app-ns -o jsonpath='{.status.podIP}')
DB_IP=$(kubectl get pod database -n app-ns -o jsonpath='{.status.podIP}')

kubectl exec -n app-ns frontend -- wget -qO- --timeout=3 http://${BACKEND_IP} && echo "OK" || echo "BLOCKED"
# 預期：OK

kubectl exec -n app-ns frontend -- wget -qO- --timeout=3 http://${DB_IP} && echo "OK" || echo "BLOCKED"
# 預期：BLOCKED
```

---

# CKAD Mock Exam 01

> ⏱️ 限時 45 分鐘｜不可看提示

---

**Q1**（8 分）  
建立 Pod `webapp` 在 namespace `ckad-test`：
- image: `nginx:alpine`
- 環境變數從 ConfigMap `app-config`（key: `APP_MODE`）注入
- liveness probe：httpGet `/` port 80，每 10 秒探測
- readiness probe：httpGet `/` port 80，初始延遲 5 秒
- resources: requests cpu=100m/mem=64Mi，limits cpu=200m/mem=128Mi

---

**Q2**（10 分）  
實作 Canary 部署：
- `stable` Deployment：image=nginx:1.24，replicas=4
- `canary` Deployment：image=nginx:1.25，replicas=1
- Service `web-svc` 同時路由到兩個 Deployment（各 80%/20% 流量）

---

**Q3**（8 分）  
建立 CronJob `cleanup`：
- schedule: 每天 02:00
- image: busybox，執行 `echo "cleanup done"`
- 保留 2 個成功記錄，1 個失敗記錄
- concurrencyPolicy: Forbid

---

**Q4**（9 分）  
建立 Pod `secure-app` 符合以下安全需求：
- 以 user 2000 執行
- 禁止 privilege escalation
- root filesystem 唯讀
- Drop ALL capabilities
- 掛載 emptyDir 到 /tmp（寫入暫存用）

---

**Q5**（10 分）  
修復以下有問題的設定（可能有多個問題）：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-deploy
spec:
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: web
        image: nginx
        livenessProbe:
          httpGet:
            path: /health
            port: 8080         # nginx 監聽 80，不是 8080
          initialDelaySeconds: 0
          periodSeconds: 0     # 無效值：必須 >= 1
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          failureThreshold: 0  # 無效值：必須 >= 1
```

---

### Mock Exam 01 解答

<details>
<summary>展開解答</summary>

```bash
# Q1
kubectl create namespace ckad-test
kubectl create configmap app-config -n ckad-test --from-literal=APP_MODE=prod

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: ckad-test
spec:
  containers:
  - name: web
    image: nginx:alpine
    env:
    - name: APP_MODE
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_MODE
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
EOF

# Q2
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
      track: stable
  template:
    metadata:
      labels:
        app: web
        track: stable
    spec:
      containers:
      - name: web
        image: nginx:1.24
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      track: canary
  template:
    metadata:
      labels:
        app: web
        track: canary
    spec:
      containers:
      - name: web
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web
  ports:
  - port: 80
EOF

# Q3
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleaner
            image: busybox
            command: ["echo", "cleanup done"]
EOF

# Q4
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsUser: 2000
    runAsNonRoot: true
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

# Q5 修復：
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-deploy
spec:
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: web
        image: nginx
        livenessProbe:
          httpGet:
            path: /health
            port: 80           # 修復 1：nginx 監聽 80
          initialDelaySeconds: 5
          periodSeconds: 10    # 修復 2：periodSeconds 最小值 1
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          failureThreshold: 3  # 修復 3：failureThreshold 最小值 1
EOF
```

</details>

---

# CKAD Mock Exam 02

> ⏱️ 限時 45 分鐘

**Q1**（8 分）Sidecar 模式  
建立 Pod `log-pod`，主容器 nginx 寫 access.log 到共享 Volume，sidecar busybox 每 5 秒輸出 log 行數

**Q2**（10 分）Helm  
安裝 bitnami/nginx chart，命名為 `my-web`，namespace `helm-ns`，replicas=3，NodePort=30095

**Q3**（9 分）Resource Quota  
在 namespace `quota-ns` 建立 ResourceQuota，限制：pods=10, requests.cpu=2, requests.memory=2Gi

**Q4**（8 分）NetworkPolicy  
namespace `isolated` 中，只允許帶有 `access=granted` label 的 Pod 進入任何 Pod，其他全部拒絕

**Q5**（10 分）排查與修復  
以下 Pod 在 Pending 狀態，找出所有原因並修復：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "50Gi"    # 問題 1
  nodeSelector:
    gpu: "true"           # 問題 2：節點無此 label
```

---

### Mock Exam 02 解答

<details>
<summary>展開解答</summary>

```bash
# Q1
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: log-pod
spec:
  volumes:
  - name: log-vol
    emptyDir: {}
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: log-vol
      mountPath: /var/log/nginx
  - name: log-sidecar
    image: busybox
    command: ["sh","-c","while true; do wc -l /logs/access.log 2>/dev/null || echo '0 lines'; sleep 5; done"]
    volumeMounts:
    - name: log-vol
      mountPath: /logs
EOF

# Q2
kubectl create namespace helm-ns
helm install my-web bitnami/nginx \
  -n helm-ns \
  --set replicaCount=3 \
  --set service.type=NodePort \
  --set service.nodePorts.http="30095"

# Q3
kubectl create namespace quota-ns
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: quota-ns
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: "2Gi"
EOF

# Q4
kubectl create namespace isolated
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-labeled-only
  namespace: isolated
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: granted
EOF

# Q5
# 問題 1：memory 50Gi 超出節點容量 → 降低
# 問題 2：節點無 gpu=true label → 移除 nodeSelector 或加 label
kubectl delete pod pending-pod
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"    # 修復 1
  # 移除 nodeSelector      修復 2
EOF
```

</details>

---

*CKAD Practice Labs v1.0 | Kubernetes 1.29 | 涵蓋官方考綱全五域*
