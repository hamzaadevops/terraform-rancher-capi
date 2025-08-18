# Rancher Deployment (Prime & OSS)

This repository contains setup instructions for deploying Rancher Prime and Rancher OSS on Kubernetes using Helm, with TLS provided by cert-manager and Let's Encrypt.

## Network Ports to Allow in Security Group
### Public ingress to Rancher
```
TCP 80 — Let's Encrypt HTTP-01 challenge
TCP 443 — Rancher UI/API + WebSocket connections
```
### Control plane & cluster communication
```
TCP 6443 — kube-apiserver

TCP 10250 — kubelet

TCP 10257 — controller-manager

TCP 10259 — scheduler

TCP 2379–2380 — etcd (control-plane only)

TCP/UDP 30000–32767 — NodePorts (if used)

UDP 8472 — Flannel/Canal VXLAN (if used)

TCP 179 — Calico BGP (if enabled)

UDP 51820–51821 — WireGuard (if enabled)
```

## Rancher Prime Setup
```bash
# Add Helm repos
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-prime https://charts.rancher.com/server-charts/prime
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.17.2 \
  --set prometheus.enabled=false \
  --set crds.enabled=true

# Install Rancher Prime
helm install rancher rancher-prime/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher-prime.awssolutionsprovider.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.environment=production \
  --set letsEncrypt.email=hamza@puffersoft.com \
  --set letsEncrypt.ingress.class=nginx

# Watch rollout
watch kubectl get all -n cattle-system

# Get bootstrap URL + password
echo https://rancher-prime.awssolutionsprovider.com/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
```

## Rancher OSS Setup
```bash
# Add Helm repos
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.17.2 \
  --set prometheus.enabled=false \
  --set crds.enabled=true

# Install Rancher OSS
kubectl create ns cattle-system
helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher-oss.awssolutionsprovider.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.environment=production \
  --set letsEncrypt.email=mkhalid@puffersoft.com

# Watch rollout
watch kubectl get all -n cattle-system

# Get bootstrap URL + password
echo https://rancher-oss.awssolutionsprovider.com/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
```

## Agent TLS Mode
Enable system-store trusted CAs for Rancher agents:
```bash
kubectl patch settings.management.cattle.io agent-tls-mode \
  --type merge -p '{"value":"system-store"}'
```

## DNS Setup

### Create A/AAAA records:

- rancher-prime.awssolutionsprovider.com → public IP of ingress/master node
- rancher-oss.awssolutionsprovider.com → public IP of ingress/master node
- Ensure port 80/443 are open to these IPs.
