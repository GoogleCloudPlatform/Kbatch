#!/bin/sh
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

bucket=$1

if [[ -z "${bucket}" ]]; then
  echo "Please specify the gcs bucket name to use."
  exit 1
fi

echo "Copying image cloud.png from gcs bucket ${bucket}"
gsutil cp gs://${bucket}/cloud.png /localdata/cloud.png

echo "Processing image"
./checkerboardimage -in=/localdata/cloud.png -out=/localdata/checker.png

t=$(date +%s)
resultfile="checker-${t}.png"
echo "Copying results ${resultfile} to gcs bucket ${bucket}"
gsutil cp /localdata/checker.png gs://${bucket}/${resultfile}
echo "Completed job"
