#!/bin/bash
sudo su
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
echo "TOKEN TO BE COPIED" 
cat /var/lib/rancher/rke2/server/node-token 
snap install kubectl --classic
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes


## WORKER NODE
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-agent.service
sleep 10
echo "server: https://18.143.199.252:9345" > /etc/rancher/rke2/config.yaml
echo "token: K104d6258c66a72dd581b5f5bd1b9f2b59a4343b298acfb508fcba4966b7d6205be::server:8b487efb08eb1dd8e5462497c9680e35" >> /etc/rancher/rke2/config.yaml
systemctl start rke2-agent.service
