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
# "-  This script deletes a Cloud Source Repositories for the sample app  -"
# "-  and deletes the Container Registry image for the sample app         _"
# "-                                                                      -"
# "------------------------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE}")
PROJECT=""

usage() {
  cat <<-EOF
  Usage: $0 [-p <project>]

  This script deletes a Cloud Source Repositories for the sample app and deletes
  the Container Registry image for the sample app

  Make sure you updated the variables in the jenkins.properties file

  Optional arguments:
    -p  Name of the GCP jenkins project

  Example:
    $0 -p jenkins-project
EOF
  exit 1
}

source ${ROOT}/common.sh

# Switch to project
gcloud config set project ${JENKINS_PROJECT}

# Verify which project your on
echo "Current project: $(gcloud config get-value project)"

# Delete source repo
if gcloud source repos list --filter sample-app | grep sample-app; then
  gcloud source repos delete sample-app --quiet
else
  echo "sample-app source repo does not exist"
fi

# Delete sample app images from the Container Registry
IMAGE=gcr.io/${JENKINS_PROJECT}/gceme

for digest in $(gcloud container images list-tags ${IMAGE} --limit=999999 \
  --format='get(digest)'); do
    (
      gcloud container images delete -q --force-delete-tags "${IMAGE}@${digest}"
    )
done