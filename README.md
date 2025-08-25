# Rancher Deployment (Prime & OSS)

This repository contains setup instructions for deploying Rancher Prime and Rancher OSS on Kubernetes using Helm, with TLS provided by cert-manager and Let's Encrypt.

## Applying the code
```bash
  git clone git@github.hmz:hamzaadevops/terraform-rancher-capi.git
  cd terraform-rancher-capi/
  terraform init
  terraform plan
  terraform apply
  terraform output capa_access_key_id
  terraform output capa_secret_access_key
```

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

## DNS Setup

### Create A/AAAA records:

- capi.awssolutionsprovider.com → public IP of ingress/master node
- rancher.awssolutionsprovider.com → public IP of ingress/master node
- Ensure port 80/443 are open to these IPs.
