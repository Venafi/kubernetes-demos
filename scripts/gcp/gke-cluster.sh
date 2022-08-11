#!/usr/bin/env bash
gcloud config set project ${1}
gcloud config set compute/region ${2}
CLUSTER_NAME=${3}

echo "Checking if cluster ${CLUSTER_NAME} exists"
if ! gcloud container clusters describe ${CLUSTER_NAME} --region ${2} > /dev/null 2>&1; then
  echo "Creating GKE cluster"
  gcloud container clusters create --release-channel=rapid --workload-pool=${1}.svc.id.goog ${CLUSTER_NAME} --region ${2} --num-nodes 3
else
  echo "Cluster already exists"
fi
echo "Configuring kubeconfig"
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${2}
