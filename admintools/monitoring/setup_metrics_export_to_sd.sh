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

set -e
set -u

GCP_PROJECT=$(gcloud config get-value project)
if [[ "$?" -ne 0 ]]; then
  echo "GCP project is not currently configured. Please use 'gcloud config set project PROJECT' and retry."
  exit -1
fi

CURRENT=$(kubectl config current-context)
GCP_REGION=$(cut -d'_' -f3 <<<${CURRENT})
KBATCH_GKE_CLUSTER=$(cut -d'_' -f4 <<<${CURRENT})

read -p "Setting up prometheus to Stackdriver metric export using sidecar container. Please refer to https://cloud.google.com/stackdriver/estimating-bills#metric-exp-usage for Stackdriver pricing.
Using Project ID: '${GCP_PROJECT}'
GCP region: '${GCP_REGION}'
Kbatch GKE Cluster: '${KBATCH_GKE_CLUSTER}'
Should sidecar be deployed using these config values? Y/n" USE_CONFIG

if [[ "$USE_CONFIG" = "n" ||  "$USE_CONFIG" = "N" ]]; then
  echo "Sidecar container is run within the kbatch-prometheus deployment."
  read -p "Please provide the GCP project id:" GCP_PROJECT
  read -p "Please provide the GCP region:" GCP_REGION
  read -p "Please provide the Kbatch GKE cluster name:" KBATCH_GKE_CLUSTER
fi

KUBE_NAMESPACE="kube-system"
SIDECAR_IMAGE_TAG=0.6.1
DATA_DIR="/prometheus"
DATA_VOLUME=prometheus-storage-volume

# Override to use a different Docker image name for the sidecar.
export SIDECAR_IMAGE_NAME=${SIDECAR_IMAGE_NAME:-'gcr.io/kbatch-images/stackdriver-prometheus-sidecar'}

kubectl -n "${KUBE_NAMESPACE}" patch deployment kbatch-prometheus-deployment --type strategic --patch "
spec:
  template:
    spec:
      containers:
      - name: sidecar
        image: ${SIDECAR_IMAGE_NAME}:${SIDECAR_IMAGE_TAG}
        imagePullPolicy: Always
        args:
        - \"--stackdriver.project-id=${GCP_PROJECT}\"
        - \"--prometheus.wal-directory=${DATA_DIR}/wal\"
        - \"--stackdriver.kubernetes.location=${GCP_REGION}\"
        - \"--stackdriver.kubernetes.cluster-name=${KBATCH_GKE_CLUSTER}\"
        ports:
        - name: sidecar
          containerPort: 9091
        volumeMounts:
        - name: ${DATA_VOLUME}
          mountPath: ${DATA_DIR}
"