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
    echo "usage: adduser.sh [options]"
    echo "       -s  | --short-name        [Required] short name used to create valid k8s resource name."
    echo "       -u  | --user-name         [One of -u or -sa is required] k8s cluster user name."
    echo "       -sa | --service-account   [One of -u or -sa is required] k8s cluster service account name."
    echo "       -n  | --namespace         [Required] namespace to add this user in."
    echo "       --project                 [Required] project id"
    echo "       --security-policy          set up security policy for the user."
    echo "                                  pass a comma separated string as: uid,group_id"
    echo "                                  example: 2000,3000"
    echo "                                  means the user will run as uid 2000,"
    echo "                                  fsgroup 3000, supplementalGroup: 3000."
    echo "                                  If group id is left blank, default is set to the same as uid. "
    echo "                                  Warning: if not set, the user can run tasks as Root!"
    echo "                                  Note: 1) please use an id larger than 2000 to avoid conflicts with GKE."
    echo "                                        2) runAsGroup is guarded by a feature gate, which is"
    echo "                                        not currently supported in GKE 1.12. fsGroup and supplemental group"
    echo "                                        are specified in the pod as group identity instead."
    echo "       --auto-pvc                 whether to create private pvc; this requires an existing nfs auto provisioner."
    echo "       --auto-pvc-storage-size    auto private pvc size, default 10G"
    echo "       --auto-pvc-storage-class   auto private pvc provisioner, default nfs-client"
    echo "       --pvcs                     other pvc names this user has access to, a comma separated list"
    echo "example: adduser.sh -s alice -u alice@example.com -n emc-lab --security-policy 7000 --auto-pvc --pvcs pvc1,pc2"
    echo "Note: this tool will not do any retry for the commands, but the errors will be printed out for debugging."
}

export short_name=
export user_name=
export buc_name=
export buc_user_id=
export namespace=
need_security_policy=
security_policy=
export k8s_name=
export uid=
export group_id=
project_id=

export access_pvcs=
export auto_pvc_name=
auto_pvc=0
export auto_pvc_storage_class="nfs-client"
export auto_pvc_storage_size="10G"

# Common names used during the kbatch set up process
auto_provisioner_app_name="nfs-client-provisioner"

# Apply a resource
apply-resource() {
yaml=$(envsubst < $1)
cat <<EOF | kubectl apply -f -
${yaml}
EOF
}

# Patch a user role
patch-role() {
patch=$(envsubst < $1)
cat <<EOF | kubectl auth reconcile -f -
${patch}
EOF
}

# Construct the batch user context.
build-batch-user-context() {
if [[ ${need_security_policy} ]]; then
  # Create batch user context with the pod security policy
  apply-resource internal/user-context-with-pod-security-policy.yaml
else
  apply-resource internal/user-context-no-pod-security-policy.yaml
fi
}

# Start to read in the command options.
while [[ $1 ]]; do
    case $1 in
        -s | --short-name )     shift
                                short_name="$1"
                                ;;
        -u | --user-name )      shift
                                user_name="$1"
                                ;;
        -sa | --service-account )  shift
                                service_account="$1"
                                ;;
        -n | --namespace )      shift
                                namespace="$1"
                                ;;
        --project )             shift
                                project_id="$1"
                                ;;
        --security-policy )     shift
                                security_policy="$1"
                                need_security_policy=1
                                ;;
        --auto-pvc )            auto_pvc=1
                                ;;
        --auto-pvc-storage-class)  shift
                                auto_pvc_storage_class="$1"
                                ;;
        --auto-pvc-storage-size)  shift
                                auto_pvc_storage_size="$1"
                                ;;
        --pvcs )                shift
                                access_pvcs="$1"
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

# Required values
if [[ -z "$user_name" && -z "$service_account" ]]; then
  usage
  exit
fi

if [[ -n "$user_name" && -n "$service_account" ]]; then
  usage
  exit
fi

if [[ -z "$short_name" || -z "$namespace" || -z "$project_id" ]]; then
  usage
  exit
fi

# check that the namespace exists
ns_exists=$(kubectl get namespace/"$namespace")
if [[ ! ${ns_exists} ]]; then
  echo "Namespace ${namespace} cannot be found!"
  exit 1
fi

# check that there is an nfs auto provisioner in cluster if --auto-pvc is specified
if (( auto_pvc == 1 )); then
  auto_provisioner_running=$(kubectl get pod --all-namespaces=true --selector=app=${auto_provisioner_app_name} -o jsonpath='{.items[0].status.phase}')
  if ! [[ "$auto_provisioner_running" == "Running" ]]; then
    echo "No nfs auto provisioner found in your cluster, please deploy one by using"
    echo "deploy_nfs_client_provisioner!"
    exit 1
  fi
fi

# parse the uid and group id if --security-context is specified
if [[ ${need_security_policy}  ]]; then
  if [[ ! ${security_policy} ]]; then
    echo "For security policy, please specify the users uid and groupid as \"uid,groupid\""
    exit 1
  fi

  index=0
  declare -a values
  # only allow 2 ids to be specified
  while (( index < 2 )); do
    cutindex=$(( index + 1 ))
    id=$(echo ${security_policy} | cut -f${cutindex} -d,)
    if [[ ${id} ]]; then
      if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "Error: $id is not an integer in security_policy."
        exit 1
      fi
      # if id is specified, assign the value to the min and max.
      values[$index]=${id}
    fi
    index=$(( $index+1 ))
  done

  uid=${values[0]}
  echo "uid is ${uid}"
  group_id=${values[1]}
  echo "group id is ${group_id}"
fi

# Give warning about user has 0 as uid
if [[ -z ${need_security_policy} || ${uid} -eq 0 ]]; then
  echo "============================= Warning ================================="
  echo "${user_name} can run as root in BatchTasks and access storage."
  echo "If this is not what you want, use --security-policy flag to set uid for this user."
  read -p "Continue? [N/y]" continue
  if [[ "$continue" != "y" && "$continue" != "Y" ]]; then
    echo "Stopped"
    exit 1
  fi
fi

# name used for kubernetes resources
k8s_name="$short_name-$namespace"

# Create BatchUserContext
# When using service accounts, sometimes the account's uniqueID, rather than the
# email address is shown under the "Submitted By" field. To handle this case,
# we add both the uniqueID and the email address as separate BatchUserContexts.
buc_name=${k8s_name}
if [[ -n ${service_account} ]]; then
  buc_user_id=${service_account}
  build-batch-user-context
  buc_name=${k8s_name}-id
  buc_user_id=$(gcloud iam service-accounts describe ${service_account} --format="value(uniqueId)")
  build-batch-user-context
else
  buc_user_id=${user_name}
  build-batch-user-context
fi

# create roles for this user
apply-resource internal/add-user-roles.yaml

# if enabled, create private pvc for this user.
if (( auto_pvc == 1 )); then
  auto_pvc_name="$k8s_name"
  apply-resource internal/user-private-pvc.yaml
  internal/config-pvc-nfs-dir.sh "$auto_pvc_name" "$namespace" "$uid" "$group_id"
  access_pvcs="$auto_pvc_name,$access_pvcs"
fi

# patch pvc roles if necessary
if [[ ${access_pvcs} ]]; then
  patch-role internal/pvc-patch-role.yaml
fi


# create role bindings for this user, default settings as a normal user.
if [[ -n "$user_name" ]]; then
  export subject_name="$user_name"
  member="user:$user_name"
else
  export subject_name="$service_account"
  member="serviceAccount:$service_account"
fi
export subject_kind="User"
export subject_api_group="rbac.authorization.k8s.io"
export subject_namespace=""

apply-resource internal/user-role-bindings.yaml

# Add IAM related bindings
gcloud projects add-iam-policy-binding ${project_id} --member=${member} --role=projects/${project_id}/roles/BatchUser > /dev/null
gcloud projects add-iam-policy-binding ${project_id} --member=${member} --role=roles/logging.viewer > /dev/null
