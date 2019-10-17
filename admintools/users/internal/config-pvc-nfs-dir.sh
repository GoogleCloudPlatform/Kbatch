#!/usr/bin/env bash
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


# This script will do:
# 1, create a pod in the namespace and mount the pvc to that pod
# 2, change the owner uid and group id
# 3, change the mod to be rxw for owner and rx for group.
# 4, delete the pod
# This pod has to be run as ROOT! so please make sure that only the system admin has the permission
# to create pod directly and and run as root.

# Input parameters
export pvc="$1"
export namespace="$2"
uid="$3"
group_id="$4"

# Set the mount point name to be /<pvc-name> in the pod.
export mountPointDir="/${pvc}"

echo "Configure nfs dir for pvc ${pvc}/${namespace} with uid ${uid}, group id ${group_id}"

# check uid and group id
if [[ -z "$uid" || -z "$group_id" ]]; then
  echo "No uid or group id specified, nfs directory will owned by Root"
  exit 0
fi

# check that the pvc is created and in Bound state.
pvc_bound=""
while [[ "$pvc_bound" != "Bound" ]]; do
  sleep 3
  echo "PVC ${pvc} is in phase ${pvc_bound} not in Bound phase, waiting ..."
  pvc_bound=$(kubectl get pvc ${pvc} -n ${namespace} -o jsonpath='{.status.phase}')
done

# create a util pod with the pvc mounted
export podName="nfs-util-$RANDOM"
# It's expected that this script is run from the add-user.sh script up one level
# from here, so, we must specify the "internal" subfolder.
yaml=$(envsubst < internal/util-pod.yaml)
cat <<EOF | kubectl create -f -
${yaml}
EOF

pod=
while [[ ! ${pod} ]]; do
  echo "Waiting for remote pod to be ready ..."
  phase=$(kubectl get pod/${podName} --namespace=${namespace} -o=jsonpath='{.status.phase}')
  if [[ "$phase" == "Running" ]]; then
    pod="$podName"
  fi
  sleep 3
done

# change the own/grp and file access mode on the pvc
exitCode=0
kubectl exec --namespace="$namespace" "$podName" chown "$uid" "$mountPointDir"
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to change the owner id"
  exitCode=1
fi
kubectl exec --namespace="$namespace" "$podName" chgrp "$group_id" "$mountPointDir"
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to change the group id"
  exitCode=1
fi
kubectl exec --namespace="$namespace" "$podName" chmod 750 "$mountPointDir"
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to change the access mode"
  exitCode=1
fi

echo "Please verify that directory ${mountPointDir} has owner id as ${uid}, group id as ${group_id} and access mode is 750:"
# show the results
kubectl exec --namespace="$namespace" "$podName" -- ls -lrt / | grep "$pvc"

# clean up the utility pod
kubectl delete pod/${podName} --namespace=default
if [[ "$?" -ne 0 ]] ; then
  echo "Failed to delete the nfs util pod, please clean it up manually with:"
  echo "kubectl delete pod/${podName} -n ${namespace}"
  exitCode=1
fi

exit ${exitCode}