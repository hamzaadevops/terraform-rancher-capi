1) Find the correct CAPA AMIs for v1.31 in ap-southeast-1
```bash
# Set your target k8s version (patch as needed)
export TARGET_OS="ubuntu-24.04"
export REGION="ap-southeast-1"

# List Ubuntu CAPA AMIs for your region/version
clusterawsadm ami list --kubernetes-version  --os ubuntu 
$ clusterawsadm ami list  --os=${TARGET_OS}   --region ${REGION}
KUBERNETES VERSION   REGION           OS             NAME                                       AMI ID
v1.32.0              ap-southeast-1   ubuntu-24.04   capa-ami-ubuntu-24.04-v1.32.0-1746714392   ami-06f54e4bde7e48fa1
v1.31.0              ap-southeast-1   ubuntu-24.04   capa-ami-ubuntu-24.04-v1.31.0-1739348996   ami-0869f49009cd96a92
v1.30.8              ap-southeast-1   ubuntu-24.04   capa-ami-ubuntu-24.04-v1.30.8-1739360448   ami-08899c9f763a3fc77
v1.30.5              ap-southeast-1   ubuntu-24.04   capa-ami-ubuntu-24.04-v1.30.5-1728924607   ami-083f201fbf9163317
v1.30.2              ap-southeast-1   ubuntu-24.04   capa-ami-ubuntu-24.04-v1.30.2-1729082892   ami-0ea84a8286e5a2933

# We will be using v1.31.0 as target version with this AMI capa-ami-ubuntu-24.04-v1.31.0-1739348996
export CP_AMI="ami-0869f49009cd96a92"   # from the list
export WK_AMI="ami-0869f49009cd96a92"   # can be the same as CP_AMI if desired

```

2) Create new AWSMachineTemplates (immutable best practice)
```yaml
root@ip-172-31-14-6:~# cat AWSMachineTemplate.yml 
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: AWSMachineTemplate
metadata:
  name: my-cluster-control-plane-template-v131
  namespace: default
spec:
  template:
    spec:
      iamInstanceProfile: nodes.cluster-api-provider-aws.sigs.k8s.io 
      instanceType: t3.medium 
      sshKeyName: rancher-prime-key
      ami:
        id: ami-0869f49009cd96a92            # substitute
      cloudInit:
        insecureSkipSecretsManager: true
      # copy other fields you need (iamInstanceProfile, subnet, tags) from the existing template
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: AWSMachineTemplate
metadata:
  name: my-cluster-worker-template-v131
  namespace: default
spec:
  template:
    spec:
      iamInstanceProfile: nodes.cluster-api-provider-aws.sigs.k8s.io 
      instanceType: t3.medium 
      sshKeyName: rancher-prime-key
      ami:
        id: ami-0869f49009cd96a92            # substitute
      cloudInit:
        insecureSkipSecretsManager: true
      # copy other fields you need (iamInstanceProfile, subnet, tags) from the existing template
```

```bash
$ vi AWSMachineTemplate.yml
$ kubectl apply -f AWSMachineTemplate.yml 
awsmachinetemplate.infrastructure.cluster.x-k8s.io/my-cluster-control-plane-template-v131 created
awsmachinetemplate.infrastructure.cluster.x-k8s.io/my-cluster-worker-template-v131 created
$ kubectl get AWSMachineTemplate
NAME                                     AGE
my-cluster-control-plane                 94m
my-cluster-control-plane-template-v131   11s
my-cluster-md-0                          94m
my-cluster-worker-template-v131          11s
```
3) Upgrade the control plane first
Bump spec.version to v1.31.x and switch the machineTemplate.infrastructureRef to the new CP template. This triggers a safe rolling replacement of the single control-plane node to 1.31. (The “change KCP.spec.version” method is the official path.
```bash
kubectl patch kubeadmcontrolplane my-cluster-control-plane --type merge -p "{
  \"spec\": {
    \"version\": \"v1.31.0\",
    \"machineTemplate\": {
      \"infrastructureRef\": {
        \"apiVersion\": \"infrastructure.cluster.x-k8s.io/v1beta2\",
        \"kind\": \"AWSMachineTemplate\",
        \"name\": \"my-cluster-control-plane-template-v131\"
      }
    }
  }
}"
# After about 96 seconds
$ KUBECONFIG=my-cluster.kubeconfig kubectl get node
NAME                                              STATUS     ROLES           AGE   VERSION
ip-10-0-136-132.ap-southeast-1.compute.internal   Ready      control-plane   92m   v1.30.8
ip-10-0-202-102.ap-southeast-1.compute.internal   NotReady   control-plane   30s   v1.31.0
ip-10-0-64-103.ap-southeast-1.compute.internal    Ready      <none>          53m   v1.30.8
ip-10-0-74-10.ap-southeast-1.compute.internal     Ready      <none>          92m   v1.30.8

# Wait until the new control plane node is Ready, then delete the old one
$ KUBECONFIG=my-cluster.kubeconfig kubectl get node
NAME                                              STATUS   ROLES           AGE     VERSION
ip-10-0-202-102.ap-southeast-1.compute.internal   Ready    control-plane   4m17s   v1.31.0
ip-10-0-64-103.ap-southeast-1.compute.internal    Ready    <none>          56m     v1.30.8
ip-10-0-74-10.ap-southeast-1.compute.internal     Ready    <none>          95m     v1.30.8
```
# 4) Upgrade the workers (MachineDeployment)
```bash
kubectl patch machinedeployment my-cluster-md-0 -n default --type merge -p "{
  \"spec\": {
    \"template\": {
      \"spec\": {
        \"version\":  \"v1.31.0\",
        \"infrastructureRef\": {
          \"apiVersion\": \"infrastructure.cluster.x-k8s.io/v1beta2\",
          \"kind\": \"AWSMachineTemplate\",
          \"name\": \"my-cluster-worker-template-v131\"
        }
      }
    }
  }
}"
```

5) Validation
```bash
kubectl get kubeadmcontrolplane my-cluster-control-plane
kubectl get machinedeployment my-cluster-md-0 -n default -o wide
$ KUBECONFIG=my-cluster.kubeconfig kubectl get nodes -o wide
$ KUBECONFIG=my-cluster.kubeconfig kubectl get pod -A -o wide
```
# Quick rollback (if ever needed)
- **Workers:** point the MD back to the previous AWSMachineTemplate and set spec.template.spec.version back to v1.30.8. This rolls back nodes.
- **Control plane:** set KubeadmControlPlane.spec.version back to v1.30.8 and flip machineTemplate.infrastructureRef.name back to the old template. Wait for the rolling replacement to complete.
```
(Use the same patch commands, just substitute the old version/template names.)
```
