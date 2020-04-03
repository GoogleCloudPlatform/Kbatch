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


usage() {
    echo "usage: deleteuser.sh [options]"
    echo "       -s  | --short-name           [Required] short name used for user roles."
    echo "       -n  | --namespace            [Required] namespace to remove this user from."
    echo "       -sa | --service-account      if the role is a service account" 
    echo "       -c  | --cluster              if this user's cluster role and cluster role binding should be deleted too"
    echo "example: deleteuser.sh -s alice -n default"
    echo "Note: this tool will NOT do any retry for the commands, but the errors will be printed out for debugging."
    echo "Note: this script will NOT delete any BatchTasks or PVCs created by this user."
}

short_name=
namespace=
clean_cluster=0
label_prefix=kbatch.io

while [[ $1 ]]; do
    case $1 in
        -s  | --short-name )      shift
                                  short_name="$1"
                                  ;;
        -n  | --namespace )       shift
                                  namespace="$1"
                                  ;;
        -c  | --cluster )         clean_cluster=1
                                  ;;
        -sa | --service-account ) service_account=1
                                  ;;                                
        * )                       usage
                                  exit 1
    esac
    shift
done

if [[ -z "$short_name" || -z "$namespace" ]]; then
  usage
  exit
fi

# find the username label from the batchusercontext
labelusername=$(kubectl get batchusercontext ${short_name}-${namespace} -o=jsonpath='{.metadata.labels.kbatch\.k8s\.io\/username}')

# delete role and role binding in namespace
kubectl delete rolebinding ${short_name}-${namespace} -n ${namespace}
kubectl delete role ${short_name}-${namespace} -n ${namespace}
# delete all the dynamic roles with this label
kubectl delete role -n ${namespace} -l ${label_prefix}/username=${labelusername}
kubectl delete rolebindings -n ${namespace} -l ${label_prefix}/username=${labelusername}

# delete cluster role and role binding
if (( clean_cluster == 1 )); then
  kubectl delete clusterrolebinding ${short_name}-crb
  kubectl delete clusterrole ${short_name}-cr
  kubectl delete clusterrolebinding -l ${label_prefix}/username=${labelusername}
  kubectl delete clusterrole -l ${label_prefix}/username=${labelusername}
fi

# delete batch user context in the name space.
kubectl delete batchusercontext ${short_name}-${namespace} -n ${namespace}
if (( service_account == 1 )); then
  kubectl delete batchusercontext ${short_name}-${namespace}-id -n ${namespace}
fi
