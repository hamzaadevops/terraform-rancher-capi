## RKE2 Setup for Management Cluster
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

### clusterawsadm

 https://cluster-api-aws.sigs.k8s.io/quick-start#initialization-for-common-providers:~:text=Initialization%20for%20common%20providers


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

curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.8.4/clusterawsadm-linux-amd64 -o clusterawsadm
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin

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

# Your management cluster has been initialized successfully!
# You can now create your first workload cluster by running the following:
  # clusterctl generate cluster [name] --kubernetes-version [version] | kubectl apply -f -
```

### First Child Cluster
```bash
# Required Vars
# You need to export these before running clusterctl generate cluster:
# 👉 Note: AWS_SSH_KEY_NAME must match a keypair you already created in AWS (aws ec2 create-key-pair --key-name my-keypair).

export AWS_REGION=ap-southeast-1                     # pick your AWS region
export AWS_SSH_KEY_NAME=rancher-prime-key              # existing EC2 keypair name in that region
export AWS_CONTROL_PLANE_MACHINE_TYPE=t3.medium # instance type for control plane
export AWS_NODE_MACHINE_TYPE=t3.medium          # instance type for workers

clusterawsadm ami list   --kubernetes-version=v1.30.8   --os=ubuntu-24.04   --region=ap-southeast-1

clusterctl generate cluster my-cluster \
  --infrastructure aws \
  --kubernetes-version v1.30.8 \
  --worker-machine-count=2 \
  --control-plane-machine-count=1 > my-cluster.yaml

kubectl apply -f my-cluster.yaml
```

## Confirmation of Creation:
```bash
kubectl get cluster
kubectl get awscluster
kubectl get machines
kubectl get kubeadmcontrolplane 
NAME                       CLUSTER      INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE    VERSION
my-cluster-control-plane   my-cluster   true                                 1                  1         1             137m   v1.30.8

clusterctl get kubeconfig my-cluster > my-cluster.kubeconfig
```

## CleanUp process

```bash
kubectl delete -f my-cluster.yaml
aws cloudformation delete-stack  --stack-name cluster-api-provider-aws-sigs-k8s-io
terrafrom destroy
```