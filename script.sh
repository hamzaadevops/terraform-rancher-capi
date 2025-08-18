#!/bin/bash
sudo su
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
echo "TOKEN TO BE COPIED" 
cat /var/lib/rancher/rke2/server/node-token 
snap install kubectl --classic
snap install helm --classic
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes


## WORKER NODE
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
sleep 10
echo "server: https://18.141.161.6:9345" > /etc/rancher/rke2/config.yaml
echo "token: K105d0098de9eb97fc7a906d02a5540df79f22432dff59a75dbc33f8162708bd360::server:12b00d9e56e39b7ea08c832b377d1fd6" >> /etc/rancher/rke2/config.yaml
systemctl start rke2-agent.service
