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


# This script can be used to submit checkerboard job with ksub using the following ksub
# command -
# ./ksub run_checkerboard_with_ksub.sh

#KB Jobname checkerboard-
#KB Namespace default
#KB Image gcr.io/kbatch-images/checkerboardimage/checkerboardimage:latest
#KB Queuename default
#KB MaxWallTime 5m
#KB MinCpu 1.0
#KB MinMemory 2Gi
#KB Mount fs-volume /mnt/pv

echo "Starting job checkerboard"
# checkerboardimage is in /app directory.
cd /app
./checkerboardimage -in=/mnt/pv/cloud.png -out=/mnt/pv/checker.png
echo "Completed job checkerboard"
