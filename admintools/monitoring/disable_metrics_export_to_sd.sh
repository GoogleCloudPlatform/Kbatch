#!/bin/bash
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

echo "This script will disable exporting metrics from kbatch-prometheus to Stackdriver."

GCP_PROJECT=$(gcloud config get-value project)
if [[ "$?" -ne 0 ]]; then
  echo "GCP project is not currently configured. Please use 'gcloud config set project PROJECT' and retry."
  exit -1
fi

CURRENT=$(kubectl config current-context)
GCP_REGION=$(cut -d'_' -f3 <<<${CURRENT})
KBATCH_GKE_CLUSTER=$(cut -d'_' -f4 <<<${CURRENT})

read -p "
Using Project ID: '${GCP_PROJECT}'
GCP region: '${GCP_REGION}'
Kbatch GKE Cluster: '${KBATCH_GKE_CLUSTER}'
Should these config values be used to disable exporting metrics to Stackdriver? Y/n " USE_CONFIG

if [[ "$USE_CONFIG" = "n" ||  "$USE_CONFIG" = "N" ]]; then
  read -p "Please provide the GCP project id:" GCP_PROJECT
  read -p "Please provide the GCP region:" GCP_REGION
  read -p "Please provide the Kbatch GKE cluster name:" KBATCH_GKE_CLUSTER

  gcloud config set project ${GCP_PROJECT} && gcloud container clusters get-credentials ${KBATCH_GKE_CLUSTER} --zone ${GCP_REGION}
fi

kubectl delete deployment/kbatch-prometheus-deployment -n kube-system
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to find kbatch-prometheus-deployment."
  exit 1
fi

kubectl apply -f deployment.yaml

echo "Please refer to https://cloud.google.com/monitoring/workspaces/guide#disabling-monitoring for disabling Stackdriver monitoring."