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


# This script applies all of the base YAML files needed for the sample jobs in the proper order.
# All resources are created in the default namespace.
kubectl apply -R -f batchpriority/
kubectl apply -R -f batchcostmodel/
kubectl apply -R -f batchbudget/
kubectl apply -R -f batchjobconstraint/
kubectl apply -R -f batchqueue/
kubectl apply -R -f batchusercontext/
