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

## Cluster API Setup
### Basic Setup
```bash
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.10.5/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl
sudo mv clusterctl /usr/local/bin/

apt install unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws configure # just get the credentials form terraform output
```

### Management Cluster
```bash
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

export AWS_B64ENCODED_CREDENTIALS=$(cat <<EOF | base64 | tr -d '\n'
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
)

clusterctl init --infrastructure aws

# Your management cluster has been initialized successfully!
# You can now create your first workload cluster by running the following:
  # clusterctl generate cluster [name] --kubernetes-version [version] | kubectl apply -f -
```

### First Child Cluster
```bash
# Required Vars
# You need to export these before running clusterctl generate cluster:

export AWS_REGION=ap-southeast-1                     # pick your AWS region
export AWS_SSH_KEY_NAME=rancher-prime-key              # existing EC2 keypair name in that region
export AWS_CONTROL_PLANE_MACHINE_TYPE=t3.medium # instance type for control plane
export AWS_NODE_MACHINE_TYPE=t3.medium          # instance type for workers

clusterawsadm ami list   --kubernetes-version=v1.30.8   --os=ubuntu-22.04   --region=ap-southeast-1

# 👉 Note: AWS_SSH_KEY_NAME must match a keypair you already created in AWS (aws ec2 create-key-pair --key-name my-keypair).
clusterctl generate cluster my-cluster \
  --infrastructure aws \
  --kubernetes-version v1.30.8 \
  --worker-machine-count=2 \
  --control-plane-machine-count=1 > my-cluster.yaml

kubectl apply -f my-cluster.yaml
```
### clusterawsadm 

 https://cluster-api-aws.sigs.k8s.io/quick-start#initialization-for-common-providers:~:text=Initialization%20for%20common%20providers

```bash
curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.8.4/clusterawsadm-linux-amd64 -o clusterawsadm
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin

export AWS_REGION=us-east-1 # This is used to help encode your environment variables
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_SESSION_TOKEN=<session-token> # If you are using Multi-Factor Auth.

# The clusterawsadm utility takes the credentials that you set as environment
# variables and uses them to create a CloudFormation stack in your AWS account
# with the correct IAM resources.
clusterawsadm bootstrap iam create-cloudformation-stack

# Create the base64 encoded credentials using clusterawsadm.
# This command uses your environment variables and encodes
# them in a value to be stored in a Kubernetes Secret.
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

# Finally, initialize the management cluster
clusterctl init --infrastructure aws

```

## DNS Setup

### Create A/AAAA records:

- capi.awssolutionsprovider.com → public IP of ingress/master node
- rancher.awssolutionsprovider.com → public IP of ingress/master node
- Ensure port 80/443 are open to these IPs.
