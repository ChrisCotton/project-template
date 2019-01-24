#!/usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# "---------------------------------------------------------"
# "-                                                       -"
# "-  snapshot regional PD for jenkins                     -"
# "-                                                       -"
# "---------------------------------------------------------"
#JENKINS_PROJECT=pso-helmsman-cicd
REGION=us-west1
PD_DISK_NAME=$(gcloud beta compute disks list --filter="labels.data:jenkins-data" --format='value(name)')
echo "PD disk name is:${PD_DISK_NAME}"
DATE=$(date +%Y%m%d)
SNAPSHOT_NAME="ci-gflocks-${DATE}"
gcloud beta compute disks snapshot "${PD_DISK_NAME}" --async --snapshot-names="${SNAPSHOT_NAME}"  --region="${REGION}"
