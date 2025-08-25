## RKE2 Setup for Management Cluster
### On Master Node
Run the following using root user
```bash
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
echo "TOKEN TO BE COPIED" 
cat /var/lib/rancher/rke2/server/node-token 
snap install kubectl --classic
snap install helm --classic
mkdir -p ~/.kube
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
kubectl get nodes
```

### On Worker Nodes
```bash
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
sleep 10
echo "server: https://MASTER_NODE_IP:9345" > /etc/rancher/rke2/config.yaml
echo "token: JOIN::server:Token" >> /etc/rancher/rke2/config.yaml
systemctl start rke2-agent.service
```

## Rancher OSS Setup
### Basic SetUp
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
helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher-oss.awssolutionsprovider.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.environment=production \
  --set letsEncrypt.email=mkhalid@puffersoft.com \
  --set letsEncrypt.ingress.class=nginx \
  --version 2.11.3

# Watch rollout
watch kubectl get all -n cattle-system

# Get bootstrap URL + password
echo https://rancher-oss.awssolutionsprovider.com/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
```

### Agent TLS Mode
Enable system-store trusted CAs for Rancher agents:
```bash
kubectl patch settings.management.cattle.io agent-tls-mode \
  --type merge -p '{"value":"system-store"}'
```
