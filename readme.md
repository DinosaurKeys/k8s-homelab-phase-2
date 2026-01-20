
## Phase 2
## What You're Creating

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    NGINX INGRESS COMPONENTS                                 │
│                                                                             │
│  ┌─────────────┐                                                           │
│  │ IngressClass│  "I handle Ingresses with class=nginx"                    │
│  └──────┬──────┘                                                           │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     DaemonSet (controller)                          │   │
│  │                                                                     │   │
│  │   worker-1          worker-2          worker-3                      │   │
│  │   ┌──────────┐     ┌──────────┐     ┌──────────┐                   │   │
│  │   │ nginx    │     │ nginx    │     │ nginx    │                   │   │
│  │   │ :80/:443 │     │ :80/:443 │     │ :80/:443 │                   │   │
│  │   └──────────┘     └──────────┘     └──────────┘                   │   │
│  │       ▲                 ▲                 ▲                         │   │
│  │       │                 │                 │                         │   │
│  │       └─────────────────┴─────────────────┘                         │   │
│  │                         │                                           │   │
│  │              Watches Ingress resources                              │   │
│  │              Updates nginx.conf                                     │   │
│  │              Routes traffic to Services                             │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│  │ServiceAcct  │────▶│   RBAC      │────▶│  ConfigMap  │                   │
│  │(identity)   │     │(permissions)│     │(nginx conf) │                   │
│  └─────────────┘     └─────────────┘     └─────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Run Where?

**All commands: control-plane-1**

---

## Step 1: Review the Manifests

Before applying, understand what each file does:

```
manifests/nginx-ingress/
├── 00-namespace.yaml      # Creates ingress-nginx namespace
├── 01-serviceaccount.yaml # Identity for controller pods
├── 02-rbac.yaml           # Permissions (ClusterRole, Role, Bindings)
├── 03-configmap.yaml      # NGINX configuration
├── 04-daemonset.yaml      # The actual controller pods
├── 05-service.yaml        # Internal service for metrics/DNS
└── 06-ingressclass.yaml   # Registers "nginx" as available class
```

---

## Step 2: Apply All Manifests

```bash
# Apply in order (namespace first!)
kubectl apply -f manifests/nginx-ingress/00-namespace.yaml
kubectl apply -f manifests/nginx-ingress/01-serviceaccount.yaml
kubectl apply -f manifests/nginx-ingress/02-rbac.yaml
kubectl apply -f manifests/nginx-ingress/03-configmap.yaml
kubectl apply -f manifests/nginx-ingress/04-daemonset.yaml
kubectl apply -f manifests/nginx-ingress/05-service.yaml
kubectl apply -f manifests/nginx-ingress/06-ingressclass.yaml

# OR apply all at once (Kubernetes handles order)
kubectl apply -f manifests/nginx-ingress/
```

**Expected output:**
```
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
configmap/ingress-nginx-controller created
daemonset.apps/ingress-nginx-controller created
service/ingress-nginx-controller created
service/ingress-nginx-metrics created
ingressclass.networking.k8s.io/nginx created
```

---

## Step 3: Wait for Pods

```bash
echo "=== Waiting for NGINX Ingress pods ==="
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

## Step 4: Verify Installation

```bash
echo "=== Pods (should be 3 - one per worker) ==="
kubectl get pods -n ingress-nginx -o wide

echo ""
echo "=== DaemonSet status ==="
kubectl get daemonset -n ingress-nginx

echo ""
echo "=== IngressClass ==="
kubectl get ingressclass

echo ""
echo "=== Services ==="
kubectl get svc -n ingress-nginx
```

**Expected output:**
```
NAME                              READY   STATUS    NODE
ingress-nginx-controller-xxxxx    1/1     Running   worker-1
ingress-nginx-controller-yyyyy    1/1     Running   worker-2
ingress-nginx-controller-zzzzz    1/1     Running   worker-3

NAME                       DESIRED   CURRENT   READY   UP-TO-DATE
ingress-nginx-controller   3         3         3       3

NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       ...
```

---

## Step 5: Verify Ports Are Listening

```bash
# Test port 80 on each worker
echo "=== Testing port 80 on workers ==="

echo ""
echo "=== Testing port 443 on workers ==="
for worker in worker-1 worker-2 worker-3; do
  echo -n "$worker:443 - "
  curl -sk -o /dev/null -w "%{http_code}" https://$worker:443 --max-time 2 || echo "failed"
  echo ""
done
```

**Expected:** `404` status code - this is correct! NGINX is responding but no routes configured.

---

## Step 6: Test with Sample Application

```bash
# Create test namespace and app
kubectl create namespace test-ingress

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: test-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hello
  namespace: test-ingress
spec:
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello
  namespace: test-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: hello.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello
            port:
              number: 80
EOF
```

---

## Step 7: Test the Ingress

```bash
# Wait for test pods
kubectl wait --namespace test-ingress \
  --for=condition=Ready pod \
  --selector=app=hello \
  --timeout=60s

# Test using Host header
echo "=== Testing Ingress routing ==="
curl -H "Host: hello.local" http://worker-1:80
```

**Expected output:**
```
Server address: 10.16.x.x:80
Server name: hello-xxxxx
Date: ...
URI: /
Request ID: ...
```

If you see this, **NGINX Ingress is working!**

---

## Step 8: Cleanup Test

```bash
kubectl delete namespace test-ingress
```

---

## Understanding What You Created

### Why hostNetwork?

```
WITHOUT hostNetwork:                    WITH hostNetwork:

  Client                                  Client
    │                                       │
    ▼                                       ▼
┌─────────┐                             ┌─────────┐
│ NodePort│  :30080                     │ Worker  │  :80
│ Service │                             │  Node   │
└────┬────┘                             └────┬────┘
     │                                       │
     ▼                                       │ (directly in pod)
┌─────────┐                                  │
│kube-proxy                                  ▼
│  rules  │                             ┌─────────┐
└────┬────┘                             │  NGINX  │
     │                                  │   Pod   │
     ▼                                  └─────────┘
┌─────────┐
│  NGINX  │
│   Pod   │
└─────────┘

Extra hop, NAT translation             Direct, no NAT
Port 30000+ range only                 Standard ports 80/443
```

### Why DaemonSet not Deployment?

```
DEPLOYMENT (replicas=2):               DAEMONSET:

   Could land anywhere                    Guaranteed on every node

   worker-1: nginx, nginx                 worker-1: nginx
   worker-2: (empty)                      worker-2: nginx
   worker-3: (empty)                      worker-3: nginx
   
   Traffic to worker-2 = FAIL            Traffic to any worker = OK
```

---

## Troubleshooting

### Pods not scheduling?

```bash
# Check if control-plane taint is blocking
kubectl describe node worker-1 | grep -i taint

# Check DaemonSet status
kubectl describe daemonset -n ingress-nginx ingress-nginx-controller
```

### Port 80/443 in use?

```bash
# Check what's using the port
ssh worker-1 "sudo ss -tlnp | grep ':80'"

# Common culprits: apache2, nginx (system), docker proxy
ssh worker-1 "sudo systemctl stop apache2 nginx"
```

### RBAC errors in logs?

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

# Look for "forbidden" or "cannot" messages
```

### 502 Bad Gateway?

```bash
# Backend service not reachable
# Check if your app pods are running
kubectl get pods -n <your-app-namespace>

# Check if service endpoints exist
kubectl get endpoints -n <your-app-namespace>
```

