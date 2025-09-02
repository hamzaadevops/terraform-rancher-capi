## 🔹 1. Control Plane Instance Type

```yaml
spec:
  template:
    spec:
      instanceType: t3.medium   # current
```

* `t3.medium` is okay for dev/test, but for small workloads you can go cheaper:

  * **t3.small** or **t3.micro** (if you’re just testing).
  * For production, stick to at least `t3.medium` for stability.

⚠️ Don’t go too small if you plan to run heavy workloads on the control plane.

---

## 🔹 2. Worker Node Instance Type

```yaml
instanceType: t3.medium   # in my-cluster-md-0
```

* Same story as above:

  * For test/dev → **t3.small** or **t3.micro**.
  * For production → consider **t3a.large** (cheaper AMD-based) or **spot instances**.

---

## 🔹 3. Number of Nodes

```yaml
replicas: 1   # control plane
replicas: 2   # workers
```

* Control plane:

  * `1` replica → cheapest, but no HA.
  * `3` replicas → recommended for prod, but costs more.
* Workers:

  * Drop from `2` → `1` if just testing.
  * Use **Cluster Autoscaler** with min=1, max=N for elasticity.

---

## 🔹 4. Load Balancer

```yaml
controlPlaneLoadBalancer:
  loadBalancerType: nlb   # current
```

* **NLBs are more expensive**. For testing, switch to `classic` (CLB):

  ```yaml
  loadBalancerType: classic
  ```
* For production, keep `nlb` (better performance and TLS termination).

---

## 🔹 5. Storage (EBS Volumes)

By default, **AWSMachineTemplate** provisions gp2 volumes of 8–20GB.

You can shrink:

```yaml
spec:
  rootVolume:
    size: 8
    type: gp3
```

* Use **gp3** instead of gp2 → \~20% cheaper.
* Only allocate the size you actually need.

---

## 🔹 6. Spot Instances for Workers

For worker MachineDeployments, add:

```yaml
spec:
  template:
    spec:
      spotMarketOptions: {}
```

This makes workers **spot instances**, cutting costs by 70–80%.
⚠️ Good for dev/test; risky for production unless workloads are tolerant of interruptions.

---

## 🔹 7. Region Selection

You’re using:

```yaml
region: ap-southeast-1
```

This is Singapore (expensive).

* For cost optimization → consider **ap-south-1 (Mumbai)** or **us-east-1 (N. Virginia)**, which are usually cheaper.
* Stick with `ap-southeast-1` if you need low latency in SE Asia.

---

✅ **Summary of quick wins for cost savings**

* Use smaller instance types (`t3.small` or `t3.micro`) for dev/test.
* Use `classic` LB instead of NLB for testing.
* Reduce replicas (e.g., 1 worker).
* Switch to `gp3` storage, shrink disk size.
* Use spot instances for workers.
* Choose a cheaper AWS region (if latency requirements allow).

