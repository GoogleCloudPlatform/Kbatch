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


# This script applies some additional YAML files needed for the imageprocess job. In particular,
# it sets up the persistent volume resources.
#
# If you want to re-run this script, picking a different filestore instance, you must first delete
# the PVC and then the PV, like
# kubectl delete -f ../defaultresources/persistentvolume/persistentvolumeclaim.yaml
# kubectl delete -f ../defaultresources/persistentvolume/persistentvolume.yaml
# Note that if you have any Pods, including completed Pods that referenced this PVC, you will
# need to delete those Pods before the PVC will be successfully deleted.

echo "Please pick a Filestore instance to use from this list:"
echo "[If you are re-running this script and picking a different Filestore instance, first see instructions in "
echo "this script file about deleting the old PVC and PV.]"
gcloud beta filestore instances list
read -p "Filestore Instance name: " INSTANCE_NAME
read -p "Filestore Zone: " ZONE
read -p "Filestore FileShare Name: " FILESTORE_FILESHARE_NAME
FILESTORE_SERVER_IP=`gcloud beta filestore instances describe ${INSTANCE_NAME} --zone=${ZONE} --format="value(networks.ipAddresses[0])"`
sed s/FILESTORE_FILESHARE_NAME/${FILESTORE_FILESHARE_NAME}/g ../defaultresources/persistentvolume/persistentvolume.yaml | sed s/FILESTORE_SERVER_IP/${FILESTORE_SERVER_IP}/g | kubectl apply -f -
kubectl apply -f ../defaultresources/persistentvolume/persistentvolumeclaim.yaml

# Add the user and give it the permission to run as root.
echo "Add necessary permissions to access NFS storage ..."
./add-admin-user.sh
