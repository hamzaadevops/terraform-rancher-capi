# rancher Prime
Allow the required ports 
Note the UDP and TCP in ports allowing


helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.17.2 \
  --set prometheus.enabled=false \
  --set crds.enabled=true 


helm repo add rancher-prime https://charts.rancher.com/server-charts/prime
helm repo update
helm install rancher rancher-prime/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher-prime.awssolutionsprovider.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
 --set letsEncrypt.environment=production \
  --set letsEncrypt.email=hamza@puffersoft.com \
  --set letsEncrypt.ingress.class=nginx

route domain to our IP of master node

echo https://rancher-prime.awssolutionsprovider.com/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')




# rancher OSS
### add repos
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

### cert-manager 
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.17.2 \
  --set prometheus.enabled=false \
  --set crds.enabled=true 


### rancher
kubectl create ns cattle-system 
helm upgrade --install rancher rancher-stable/rancher \
 --namespace cattle-system \
 --set hostname=rancher-server-mk.awssolutionsprovider.com \
 --set bootstrapPassword=admin \
 --set ingress.tls.source=letsEncrypt \
 --set letsEncrypt.environment=production \
 --set letsEncrypt.email=mkhalid@puffersoft.com
kubectl get all -n cattle-system  
