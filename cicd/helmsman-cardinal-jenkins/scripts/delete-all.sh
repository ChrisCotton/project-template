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

# "------------------------------------------------------------------------"
# "-                                                                      -"
# "-  This script run all the delete scripts                              -"
# "-                                                                      -"
# "------------------------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE}")

# Run the delete jenkins cluster script
${ROOT}/delete-jenkins-cluster.sh

# Run the delete dev cluster and service account script
${ROOT}/delete-deployment-cluster.sh -e dev

# Run the delete prod cluster and service account script
#${ROOT}/delete-deployment-cluster.sh -e prod

# Run script to delete the sample app images from the Container Registry and
# Cloud Source Repositories
#${ROOT}/delete-repo.sh