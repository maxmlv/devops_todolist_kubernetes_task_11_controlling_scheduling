#!/bin/bash
set -euo pipefail

kubectl taint nodes -l app=mysql app=mysql:NoSchedule --overwrite

kubectl apply -f .infrastructure/mysql/ns.yml
kubectl apply -f .infrastructure/mysql/configMap.yml
kubectl apply -f .infrastructure/mysql/secret.yml
kubectl apply -f .infrastructure/mysql/service.yml
kubectl apply -f .infrastructure/mysql/statefulSet.yml

kubectl apply -f .infrastructure/app/ns.yml
kubectl apply -f .infrastructure/app/pv.yml
kubectl apply -f .infrastructure/app/pvc.yml
kubectl apply -f .infrastructure/app/secret.yml
kubectl apply -f .infrastructure/app/configMap.yml
kubectl apply -f .infrastructure/app/clusterIp.yml
kubectl apply -f .infrastructure/app/nodeport.yml
kubectl apply -f .infrastructure/app/hpa.yml
kubectl apply -f .infrastructure/app/deployment.yml
kubectl apply -f .infrastructure/app/todoapp-pod.yml

# Install Ingress Controller (pinned version)
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml"

# Force controller onto the node with the hostPort mapping
kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/nodeSelector/ingress-ready","value":"true"}]'

kubectl wait --namespace ingress-nginx \
  --for=condition=complete job/ingress-nginx-admission-patch \
  --timeout=120s

kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl apply -f .infrastructure/ingress/ingress.yml

kubectl rollout status statefulset/mysql -n mysql --timeout=120s
kubectl rollout status deployment/todoapp -n todoapp --timeout=120s

echo "Deployment complete."