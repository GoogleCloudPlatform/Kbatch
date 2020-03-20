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
    echo "usage: datacopy.sh [options]"
    echo "       -l | --local         local data location [Required]"
    echo "       -r | --remote        remote data location, will be prefixed with mountPath [Required]"
    echo "       -p | --pvc           pvc name [Required]"
    echo "       -u | --upload        upload local file to remote (default)"
    echo "       -d | --download      download files from remote to local"
    echo "       -n | --namespace     namespace to use (use \"default\" namespace if unspecified)"
    echo "       -q | --queue         batch queue to use (use \"default\" queue if unspecified)"
    echo "       -m | --mount         mount path, default to jobData if not specified"
    echo "       -o | --openshell     whether to open an shell after the data is copied"
    echo "       -k | --keep          whether to keep the data copy job or not"
    echo "       -h | --help          print this usage information"
    echo "example: datacopy.sh -l src.txt -r dest.txt -p mypvc"
}

local=
remote=
export pvc=
keepjob=
openshell=
upload=1
# default namespace
export namespace="default"
# default queue name
export queue="default"
# default mount point of the volume
export mountPath="/jobdata"

# This function terminates the data util job
terminate-job() {
  jobName="$1"
  namespace="$2"
  echo "terminating ${jobName} in ${namespace}"
  kubectl patch --namespace=${namespace} batchjob/${jobName} --type merge --patch '{"spec": {"userCommand": "Terminate"}}'
  if [[ $? -ne 0 ]]; then
    echo "${jobName} termination failed, please ask your cluster admin to clean it up for you".
    exit 1
  fi
  echo "${jobName} terminated."
  exit 0
}

while [[ $1 ]]; do
    case $1 in
        -u | --upload )         upload=1
                                ;;
        -d | --download )       upload=0
                                ;;
        -l | --local )          shift
                                local="$1"
                                ;;
        -r | --remote )         shift
                                remote="$1"
                                ;;
        -p | --pvc )            shift
                                pvc="$1"
                                ;;
        -m | --mount )          shift
                                mountPath="$1"
                                ;;
        -n | --namespace )      shift
                                namespace="$1"
                                ;;
        -q | --queue )          shift
                                queue="$1"
                                ;;
        -k | --keep )           keepjob=1
                                ;;
        -o | --openshell )      openshell=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [[ ! ${local} ]]
then
      echo "Please specify a source file."
      usage
      exit
fi

if [[ ! ${remote} ]]
then
      echo "Please specify a destination."
      usage
      exit
fi

volumespec=
if [[ ! ${pvc} ]]; then
  echo ""
  echo "Please specify a pvc name."
  echo ""
  usage
  exit 1
fi

echo "local location is ${local}"
remotefilepath="${mountPath}/${remote}"
echo "remote location is ${remotefilepath}"
echo "mountPath is ${mountPath}"
echo "pvc name is ${pvc}"

# some relevant kbatch labels
kbatchLabelPrefix="kbatch.io/"
jobLabelName="${kbatchLabelPrefix}jobname"
export jobCategoryLabelName="${kbatchLabelPrefix}jobcategory"

# create a data copy util job
export jobName="data-util-$RANDOM"
export groupName="default"
echo "creating datacopy util batchjob: ${jobName}"

yaml=$(envsubst < internal/datacopy-util-batchjob.yaml)
cat <<EOF | kubectl create -f -
${yaml}
EOF

if [[ $? -ne 0 ]]; then
  echo "Failed to create data util job, exiting!"
  exit 1
fi

# wait for the pod to be running
pod=
echo "Waiting for datacopy batchjob to be ready ..."
wait_limit=100
wait_num=0
while [[ -z "$pod" && ${wait_num} -lt ${wait_limit} ]]; do
  sleep 3
  phase=$(kubectl get pods --namespace=${namespace} --selector=${jobLabelName}=${jobName} -o=jsonpath='{.items[*].status.phase}')
  if [[ "$phase" == "Running" ]]; then
    pod=$(kubectl get pods --namespace=${namespace} --selector=${jobLabelName}=${jobName} -o=jsonpath='{.items[*].metadata.name}')
  fi
  wait_num=$(( wait_num + 1 ))
done

# Batchjob is not ready within timeout limit
if [[ ! ${pod} ]]; then
  echo "Datacopy batchjob was not ready with the timeout limit; exiting."
  terminate-job ${jobName} ${namespace}
  exit 1
fi

remotelocation="${namespace}/${pod}:${remotefilepath}"
echo "Remote location is ${remotelocation}"

# copy files
if (( upload == 1 )); then
  kubectl cp ${local} ${remotelocation} --no-preserve=false
else
  kubectl cp ${remotelocation} ${local} --no-preserve=false
fi
echo "copy finished"

if (( openshell == 1 )); then
  echo "-------------- Opening a shell, type \"exit\" to exit -----------------------"
  kubectl exec --namespace=${namespace} -it ${pod} -- sh
fi

# terminate job
if [[ ! ${keepjob} ]]; then
  terminate-job ${jobName} ${namespace}
fi
