#!/bin/bash
set -e

export KUBECONFIG=~/.kube/app.config

echo "==== stop minikube ===="
MINIKUBEPROFILE="$(minikube profile list | grep '^| minikube ')" || true
if [[ "${MINIKUBEPROFILE}" != "" ]]; then
  minikube stop
  minikube delete
fi

echo "==== start minikube ===="
minikube start --memory=6g

echo "==== install app packages ===="
yarn install
export VERSION=`cat package.json | grep '^  \"version\":' | cut -d ' ' -f 4 | tr -d '",'`  # extract version from package.json
export APP=`cat package.json | grep '^  \"name\":' | cut -d ' ' -f 4 | tr -d '",'`         # extract app name from package.json
export USER=yuriyvorobyov96

echo "==== build app image ${APP}:${VERSION} ===="
docker build -t ${APP}:${VERSION} .
docker tag ${APP} ${USER}/${APP}:${VERSION}
docker push ${USER}/${APP}:${VERSION}

echo "==== create namespace ===="
kubectl create ns monitoring

echo "==== deploy application ===="
kubectl -n monitoring apply -f app.yaml

# echo "==== deploy application (namespaces, pods and services)"
# cat app.yml | envsubst | kubectl create -f - --save-config

echo "==== create cluster role ===="
kubectl create -f cluster-role.yaml

echo "==== deploy prometheus ===="
kubectl create -f prometheus-config.yaml
kubectl create -f prometheus-deployment.yaml
kubectl create -f prometheus-service.yaml

echo "==== deploy grafana ===="
kubectl create -f grafana/grafana-datasources-config.yaml
kubectl create -f grafana/grafana-dashboards-config.yaml
kubectl create -f grafana/grafana-deployment.yaml
kubectl create -f grafana/grafana-service.yaml

echo "==== DONE ===="