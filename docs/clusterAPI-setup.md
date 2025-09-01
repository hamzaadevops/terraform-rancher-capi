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
export AWS_REGION=ap-southeast-1                     # pick your AWS region

# export AWS_B64ENCODED_CREDENTIALS=$(cat <<EOF | base64 | tr -d '\n'
# [default]
# aws_access_key_id = ${AWS_ACCESS_KEY_ID}
# aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
# EOF
# )

curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.8.4/clusterawsadm-linux-amd64 -o clusterawsadm
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin

# Create the base64 encoded credentials using clusterawsadm.
# This command uses your environment variables and encodes
# them in a value to be stored in a Kubernetes Secret.
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

# The clusterawsadm utility takes the credentials that you set as environment
# variables and uses them to create a CloudFormation stack in your AWS account
# with the correct IAM resources.
clusterawsadm bootstrap iam create-cloudformation-stack


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

### Troubleshooting
If the nodes are notReady, which is expected to be not ready please check the pods
```bash
$ KUBECONFIG=my-cluster.kubeconfig kubectl get node
NAME                                              STATUS     ROLES           AGE     VERSION
ip-10-0-111-249.ap-southeast-1.compute.internal   NotReady   <none>          3m14s   v1.30.8
ip-10-0-136-132.ap-southeast-1.compute.internal   NotReady   control-plane   4m6s    v1.30.8
ip-10-0-74-10.ap-southeast-1.compute.internal     NotReady   <none>          3m12s   v1.30.8

$ KUBECONFIG=my-cluster.kubeconfig kubectl get pod -A
NAMESPACE     NAME                                                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-55cb58b774-k6bs4                                                  0/1     Pending   0          4m5s
kube-system   coredns-55cb58b774-tlmkp                                                  0/1     Pending   0          4m5s
kube-system   ebs-csi-controller-6988b9d6f6-ndxqd                                       0/6     Pending   0          4m16s
kube-system   ebs-csi-controller-6988b9d6f6-rkt8h                                       0/6     Pending   0          4m16s
kube-system   etcd-ip-10-0-136-132.ap-southeast-1.compute.internal                      1/1     Running   0          4m5s
kube-system   kube-apiserver-ip-10-0-136-132.ap-southeast-1.compute.internal            1/1     Running   0          4m5s
kube-system   kube-controller-manager-ip-10-0-136-132.ap-southeast-1.compute.internal   1/1     Running   0          4m5s
kube-system   kube-proxy-5mxzj                                                          1/1     Running   0          4m5s
kube-system   kube-proxy-vfh54                                                          1/1     Running   0          3m21s
kube-system   kube-proxy-xthbv                                                          1/1     Running   0          3m23s
kube-system   kube-scheduler-ip-10-0-136-132.ap-southeast-1.compute.internal            1/1     Running   0          4m5s
```
**Here’s the breakdown:**
- Your control plane components (etcd, kube-apiserver, kube-controller-manager, kube-scheduler) are running fine ✅.
- kube-proxy is also running.
- But coredns and other pods are Pending, which usually means no network is available for scheduling pods.
- All nodes show NotReady, which again points to the CNI missing.

**Fixing:** You need to install a CNI plugin (Cluster API clusters don’t come with one by default). The common choices are:
- Calico
- Cilium
- Weave Net
For example, to quickly install Calico:
```bash
$ KUBECONFIG=my-cluster.kubeconfig kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

$ KUBECONFIG=my-cluster.kubeconfig kubectl get pod -A
NAMESPACE     NAME                                                                      READY   STATUS    RESTARTS   AGE
kube-system   aws-cloud-controller-manager-9n779                                        1/1     Running   0          7m28s
kube-system   calico-kube-controllers-564985c589-chcc7                                  1/1     Running   0          7m44s
kube-system   calico-node-4445z                                                         1/1     Running   0          7m44s
kube-system   calico-node-qxhd7                                                         1/1     Running   0          7m44s
kube-system   calico-node-xqw77                                                         1/1     Running   0          7m44s
kube-system   coredns-55cb58b774-k6bs4                                                  1/1     Running   0          13m
kube-system   coredns-55cb58b774-tlmkp                                                  1/1     Running   0          13m
kube-system   ebs-csi-controller-6988b9d6f6-ndxqd                                       6/6     Running   0          13m
kube-system   ebs-csi-controller-6988b9d6f6-rkt8h                                       6/6     Running   0          13m
kube-system   ebs-csi-node-8kmj9                                                        3/3     Running   0          7m17s
kube-system   ebs-csi-node-j7cjq                                                        3/3     Running   0          7m16s
kube-system   etcd-ip-10-0-136-132.ap-southeast-1.compute.internal                      1/1     Running   0          13m
kube-system   kube-apiserver-ip-10-0-136-132.ap-southeast-1.compute.internal            1/1     Running   0          13m
kube-system   kube-controller-manager-ip-10-0-136-132.ap-southeast-1.compute.internal   1/1     Running   0          13m
kube-system   kube-proxy-5mxzj                                                          1/1     Running   0          13m
kube-system   kube-proxy-vfh54                                                          1/1     Running   0          13m
kube-system   kube-proxy-xthbv                                                          1/1     Running   0          13m
kube-system   kube-scheduler-ip-10-0-136-132.ap-southeast-1.compute.internal            1/1     Running   0          13m
```

## Scaling Clusters
The clusters, nodes and control plane are managed as crds in cluster API
### Control Plane Node (kubeadmcontrolplane)
```bash
$ kubectl get kubeadmcontrolplane 
NAME                       CLUSTER      INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE   VERSION
my-cluster-control-plane   my-cluster   true          true                   1          1       1         0             44m   v1.30.8

$  kubectl scale kubeadmcontrolplane my-cluster-control-plane --replicas=3
NAME                       CLUSTER      INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE   VERSION
my-cluster-control-plane   my-cluster   true          true                   2          1       2         1             51m   v1.30.8

# After 40 seconds
$ kubectl get kubeadmcontrolplane 
NAME                       CLUSTER      INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE   VERSION
my-cluster-control-plane   my-cluster   true          true                   3          2       3         1             52m   v1.30.8

# After 90 seconds
# kubectl get kubeadmcontrolplane
NAME                       CLUSTER      INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE   VERSION
my-cluster-control-plane   my-cluster   true          true                   3          3       3         0             53m   v1.30.8
```
### Worker Node (machinedeployment)
```bash
$ kubectl get machinedeployment
NAME              CLUSTER      REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE     AGE   VERSION
my-cluster-md-0   my-cluster   2          2       2         0             Running   44m   v1.30.8

$ kubectl scale machinedeployment my-cluster-md-0 --replicas=3
machinedeployment.cluster.x-k8s.io/my-cluster-md-0 scaled

$ kubectl get machinedeployment
NAME              CLUSTER      REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE       AGE   VERSION
my-cluster-md-0   my-cluster   3          2       3         1             ScalingUp   47m   v1.30.8

# After 40 seconds
$ kubectl get machinedeployment
NAME              CLUSTER      REPLICAS   READY   UPDATED   UNAVAILABLE   PHASE     AGE   VERSION
my-cluster-md-0   my-cluster   3          3       3         0             Running   47m   v1.30.8
```
### Summary:
- At creation → set --worker-machine-count and --control-plane-machine-count.
- After creation → kubectl scale machinedeployment ... (workers) or kubectl scale kubeadmcontrolplane ... (control-plane).
- For autoscaling → install Cluster Autoscaler with CAPI integration.

## CleanUp process

```bash
kubectl delete -f my-cluster.yaml
aws cloudformation delete-stack  --stack-name cluster-api-provider-aws-sigs-k8s-io
terrafrom destroy
```

ControlPlane Scale Down:
takes approximately one minute


how to use single nat?