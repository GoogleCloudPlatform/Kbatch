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

#
# Script to install an nfs auto provisioner in the kubernetes cluster kube-system namespace.
# To run this script, the user must have a cluster and be able to run kubectl
# as cluster admin.

usage() {
    echo "usage: deploy_nfs_client_provisioner.sh [gke_region] [gke_cluster_name] [filestore_zone] [filestore_instance_name]"
    echo "example: deploy_nfs_client_provisioner.sh us-west1 kbatch us-west1-b myfilestore"
}

echo "NFS PVC auto provisioner deployment"

if [[ "$#" -ne 4 ]]; then
    echo "Incorrect number of parameters"
    usage
    exit 1
fi

gke_region="$1"
gke_cluster_name="$2"
filestore_zone="$3"
filestore_instance_name="$4"

echo "gke_region: ${gke_region}"
echo "gke_cluster_name : ${gke_cluster_name}"

nfs_auto_provisioner_name="kbatch-nfs-auto-provisioner"
install_namespace="kube-system"

# check if there is an auto provisioner running already.
# if there is, let the user know that the old one will be deleted.
has_old=$(kubectl get pod -n ${install_namespace} --selector=app=nfs-client-provisioner)

if [[ ${has_old} ]]; then
  read -p "Please be aware, the old auto provisioner will be deleted in order to deploy a new one. Is this OK? [Y/n] " deploy
  if [[ "$deploy" == "n" || "$deploy" == "N" ]] ; then
    exit 0
  fi
fi

# Get access to a cluster
gcloud container clusters get-credentials "$gke_cluster_name" --region="$gke_region"
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to get cluster credentials using region; trying zone."
  exit 1
fi

echo "Current cluster context: "
kubectl config current-context
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to get current context."
  exit 1
fi

# Set up a permission on the namespace:default service account which is needed for the installation.
# TODO: cluster admin role might be too much, find the more limited role for the provisioner.
cluster_role_binding_exists=$(kubectl create clusterrolebinding kube-system-default-sa-cluster-admin-role --clusterrole=cluster-admin --serviceaccount=${install_namespace}:default 2>&1)

if [[ "$?" -ne 0 ]] ; then
  # If it already exists then it's OK, otherwise panic.
  if [[ "$cluster_role_binding_exists" != *"AlreadyExists"* ]] ; then
    echo "Failed to set permissions."
    exit 1
  fi
fi

# Install helm
echo "Installing Helm to deploy the NFS auto provisioner. You can uninstall helm after the provisioner has started."
echo "To uninstall Helm, please see https://helm.sh/docs/using_helm/#installation-frequently-asked-questions"
echo "................................."
../third_party/get_helm.sh
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to install helm."
  exit 1
fi

# helm init will deploy tiller into the cluster
helm init
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to initialize helm."
  exit 1
fi

# An NFS server ip has to be provided to install the auto provisioner.
# The server ip is determined by looking up the provided $filestore_instance_name.
echo "Searching for filestore instance ${filestore_instance_name} in zone ${filestore_zone}"
existing_server_ip=$(gcloud beta filestore instances describe ${filestore_instance_name} --zone="$filestore_zone" --format="value(networks.ipAddresses[0])")
if [[ ${existing_server_ip} ]]; then
  echo "Found existing filestore server ip: ${existing_server_ip}"
  nfs_server_ip="$existing_server_ip"
else
  echo "Failed to retrieve IP for filestore instance ${filestore_instance_name} in zone ${filestore_zone}"
  exit 1
fi

# Make sure that the tiller pod is running
tiller_is_running=
while [[ "$tiller_is_running" != "Running" ]]; do
  echo "waiting for tiller ..."
  tiller_is_running=$(kubectl get pod -n ${install_namespace} --selector=name=tiller -o jsonpath='{.items[0].status.phase}')
  sleep 5
done

# install the nfs auto provisioner into install_namespace
has_old_release="$(helm list | grep ${nfs_auto_provisioner_name} 2>&1)"
if [[ ${has_old_release} ]]; then
  echo "Deleting the old release: ${nfs_auto_provisioner_name}..."
  helm del --purge ${nfs_auto_provisioner_name}
  if [[ "$?" -ne 0 ]] ; then
    echo "Failed to delete old release of NFS auto provisioner."
    exit 1
  fi
fi
echo "Installing auto provisioner ${nfs_auto_provisioner_name} into namespace ${install_namespace} ..."
helm install --set nfs.server=${nfs_server_ip} --set nfs.path=/vol1 stable/nfs-client-provisioner --name ${nfs_auto_provisioner_name} --namespace ${install_namespace}
# Sometimes the helm installation returns transient error, but the installation is actually ok.
# A better way to verify installation is checking if the auto provisioner pod is running and created.
# The selector name is set by the helm release.
auto_provisioner_is_running=""
wait_limit=10
wait_num=0
while [[ "$auto_provisioner_is_running" != "Running" && ${wait_num} -lt ${wait_limit} ]]; do
  echo "Waiting for auto provisioner to run ..."
  auto_provisioner_is_running=$(kubectl get pod -n ${install_namespace} --selector=app=nfs-client-provisioner -o jsonpath='{.items[0].status.phase}')
  sleep 3
  wait_num=$(( wait_num+1 ))
done

if [[ "$auto_provisioner_is_running" != "Running" ]]; then
  echo "Auto Provisioner is NOT installed correctly!"
  echo "There will be issues using the nfs auto pvc feature when adding a batch user."
else
  echo "Auto provisioner is running, you can view the auto provisioner status with:"
  echo "kubectl get pod -n ${install_namespace} --selector=app=nfs-client-provisioner -o jsonpath='{.items[0].status.phase}'"
fi

read -p "Tiller is not needed anymore, uninstall it? (recommended). [Y/n]" uninstall_tiller
if [[ "$uninstall_tiller" == "n" || "$uninstall_tiller" == "N" ]] ; then
  exit 0
else
  echo "Deleting the tiller deployment..."
  kubectl delete deployment/tiller-deploy -n ${install_namespace}
  kubectl delete service/tiller-deploy -n ${install_namespace}
  echo "Done"
fi
