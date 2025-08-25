#!/bin/bash
sudo su
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


## WORKER NODE
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
sleep 10
echo "server: https://13.212.224.187:9345" > /etc/rancher/rke2/config.yaml
echo "token: K1070defbbe3c5a65423820445a461a6896b76b4249dbe88df72e716a9693db6a60::server:cb314d358673ccabf77a02efbc64c96a" >> /etc/rancher/rke2/config.yaml
systemctl start rke2-agent.service
