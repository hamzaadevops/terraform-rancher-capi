# 1) What is the Cloud Controller Manager (CCM)?

* The CCM is the control-plane component that runs cloud-specific controllers separately from kube-controller-manager. It is responsible for cloud integration tasks like:

  * Setting `spec.providerID` on Nodes and removing `node.cloudprovider.kubernetes.io/uninitialized` taints.
  * Creating/maintaining cloud load balancers for Service type=LoadBalancer.
  * Managing Routes, Node lifecycle interactions, and certain PV provisioning hooks (depending on provider). ([Kubernetes][1], [Kubernetes][2])

Why external/out-of-tree? Kubernetes removed in-tree cloud provider code to let cloud providers iterate independently, improve security, and avoid coupling. That means clusters that used to rely on in-tree behavior must run an external CCM for cloud integration. ([Kubernetes][1])

---

# 2) Why it matters for Cluster API (CAPI)

* CAPI and many bootstrap providers create nodes with taints like `node.cluster.x-k8s.io/uninitialized:NoSchedule` and kubelet started with `--cloud-provider=external` will add `node.cloudprovider.kubernetes.io/uninitialized:NoSchedule`. These taints *prevent scheduling* until:

  1. A CNI brings up networking so CAPI can finish node init (removes `node.cluster.x-k8s.io/uninitialized`).
  2. The external CCM initializes the node (sets providerID) and removes the cloud provider `uninitialized` taint.
     Result: if you don’t install CNI *and* CCM in the right order, system pods (CoreDNS, CSI, etc.) remain **Pending**. ([Cluster API][3], [Kubernetes][4])

---

# 3) Best approach (recommended) for AWS + Cluster API

**Recommended path:**

1. **Install a CNI first** (Calico, Cilium, or AWS VPC CNI) so nodes become networked and CAPI can finish bootstrapping.
2. **Install the official AWS Cloud Controller Manager (cloud-provider-aws)** as a deployment using the official Helm chart (or provided manifests). Use the Helm chart from the cloud-provider-aws project — this is the recommended user path for an existing cluster. Helm makes configuration (region, clusterName, serviceAccount) and upgrades straightforward. ([Kubernetes][2], [AWS Cloud Provider][5])

Why Helm? Official project provides a maintained chart, RBAC manifests, and easier parameterization (IAM, controller flags) and is commonly used in docs and examples. ([GitHub][6], [Chainguard Containers][7])

---

# 4) Prerequisites (must-have before installing CCM)

1. **CNI installed first** (Calico/Cilium/Flannel/AWS VPC). Otherwise cluster bootstrap taint from CAPI prevents scheduling of CNI DaemonSet. ([Cluster API][3])
2. **IAM permissions for the controller**: provide an IAM role with the necessary AWS permissions (ELB, Route53 if needed, EBS ops, tagging, EC2 read/write, etc.). Two common options:

   * **IRSA (recommended on EKS)** — attach IAM role to service account.
   * **Instance profile / node IAM role** — attach policy to nodes (for non-EKS/self-managed). ([AWS Documentation][8], [Kubernetes][2])
3. **Cluster name and region configured** — used by the cloud provider to tag/find resources.
4. **ServiceAccount & RBAC** — the chart creates them; if you use IRSA annotate the SA.
5. **Kubelet started with `--cloud-provider=external`** on nodes (CAPI + kubeadm configuration when you bootstrapped control plane). If you migrated from in-tree to external, the documented upgrade steps are in cloud-provider-aws docs. ([AWS Cloud Provider][5], [Kubernetes][2])

---

# 5) Official (Helm) install steps — example (production-friendly)

> NOTE: replace `<CLUSTER_NAME>`, `<AWS_ROLE_ARN>` or IRSA annotations according to your environment. These steps follow the cloud-provider-aws project guidance.

1. Add the Helm repo and update:

```bash
helm repo add aws-ccm https://kubernetes.github.io/cloud-provider-aws
helm repo update
```

2. Prepare `values.yaml` (example minimal):

```yaml
clusterName: my-cluster
region: ap-southeast-1
serviceAccount:
  create: true
  # If using IRSA on EKS: set annotations to the serviceAccount:
  #   annotations:
  #     eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/CCMRole
extraArgs:
  - --use-service-account-credentials=true
  - --cloud-provider=aws
nodeSelector: {}
tolerations: []
```

3. Install via Helm:

```bash
helm upgrade --install aws-cloud-controller-manager aws-ccm/aws-cloud-controller-manager \
  --namespace kube-system --create-namespace \
  --values values.yaml
```

4. Verify deployment:

```bash
kubectl -n kube-system get deploy aws-cloud-controller-manager
kubectl -n kube-system logs -l app=aws-cloud-controller-manager --tail=200
kubectl get nodes -o wide
# providerID should appear (e.g., aws:///ap-southeast-1a/i-0123abc)
kubectl describe node <node> | grep -i providerID -A2
kubectl describe node <node> | grep -i Taints -A3
```

**Sources/Examples**: official cloud-provider-aws getting started and chart releases. ([Kubernetes][2], [GitHub][6])

---

# 6) Verification checklist (what to look for after install)

* **CCM Pod(s) Running**

  ```bash
  kubectl -n kube-system get pods -l app=aws-cloud-controller-manager
  ```
* **Nodes have `spec.providerID` populated**

  ```bash
  kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.providerID}{"\n"}{end}'
  ```
* **`node.cloudprovider.kubernetes.io/uninitialized` taints removed**:

  ```bash
  kubectl describe node <node> | grep -i Taints
  ```
* **CoreDNS / CSI / other system pods schedule and become Running**:

  ```bash
  kubectl get pods -n kube-system
  ```
* **CCM logs show successful AWS calls** (ELB creation logs, node updates). ([Kubernetes][2])

---

# 7) Troubleshooting common issues & gotchas

* **CCM logs show permission denied** → check IAM policy/IRSA and ensure the role has ELB/EC2/EBS permissions. Use the official policy examples from cloud-provider-aws. ([Kubernetes][2], [Chainguard Containers][7])
* **Nodes still have `uninitialized` taint** → ensure `--cloud-provider=external` is set for kubelet or kube-controller-manager config was correctly migrated; check CCM is pointed to correct region/clusterName. ([AWS Cloud Provider][5])
* **Chicken-and-egg with services that depend on cert-manager or other controllers** — some controllers may require cert-manager; prefer to install minimal prerequisites (CNI + CCM) before optional controllers. ([Reddit][9], [Kubernetes SIGs][10])
* **Version compatibility** — use a CCM image compatible with your Kubernetes version; watch the cloud-provider-aws releases for matching versions. ([GitHub][6])

---

# 8) Quick slide bullets for your presentation (CAPI vs Rancher context)

**Cloud Controller Manager (CCM) — one slide**

* Purpose: externalize cloud API controllers (LoadBalancers, Node providerID, routes). ([Kubernetes][1])
* Why out-of-tree: decouple cloud provider development from core Kubernetes; faster security/bug fixes. ([Kubernetes][11])
* Key dependencies: CNI first (uninitialized taint removal), IAM/IRSA for AWS, correct `--cloud-provider` flags. ([Cluster API][3], [Kubernetes][2])

**Cluster API vs Rancher — one slide (short)**

* **Cluster API (CAPI)**:

  * Declarative infra/machine lifecycle, provider-agnostic, intended for GitOps and infra-as-code across clouds. Integrates tightly with CCM when using out-of-tree providers. Good for infra automation and multi-cloud reproducibility. ([Cluster API][3])
* **Rancher**:

  * Management plane + UI over clusters, simplifies cluster creation/management, can orchestrate cloud resources (includes its own workflows), often easier for day-to-day operations and RBAC via UI.
* **When CCM matters**: for both, if kubelets run with external cloud provider, both need the CCM to be installed or provided by the managed offering (Rancher may install/expect it). Use CAPI if you want full machine lifecycle control; Rancher if you want management + UI. (If you want, I can make a full slide deck.)

---

# 9) Concrete references you can link in your presentation (official)

* Kubernetes: Cloud Controller Manager concept & admin guides. ([Kubernetes][1])
* Cloud Provider AWS (getting started & Helm instructions). ([Kubernetes][2], [AWS Cloud Provider][5])
* Cluster API docs: `node.cluster.x-k8s.io/uninitialized` taint / bootstrap behavior. ([Cluster API][3])
* Kubernetes label/taint reference for `node.cloudprovider.kubernetes.io/uninitialized`. ([Kubernetes][4])

---

# 10) TL;DR: Best way to install CCM on AWS with CAPI

1. Install CNI (Calico/Cilium/AWS VPC CNI).
2. Create IAM role (IRSA for EKS or instance IAM policies) with required AWS permissions.
3. Install the **official cloud-provider-aws Helm chart** (recommended).
4. Verify CCM pods are Running, nodes get `providerID`, taints removed, system pods become Running.
