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

# "---------------------------------------------------------------"
# "-                                                             -"
# "-  Delete and uninstalls Jenkins and deletes the GKE cluster  -"
# "-                                                             -"
# "---------------------------------------------------------------"

# Do not set errexit as it makes partial deletes impossible
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE}")
PROJECT=""

usage() {
  cat <<-EOF
  Usage: $0 [-p <project> -c <cluster>]

  This script will delete and uninstalls Jenkins and deletes the GKE cluster

  Make sure you updated the variables in the jenkins.properties file

  Optional arguments:
    -p  Name of the GCP project that your cluster is in.
        Default: $JENKINS_PROJECT

    -c  Cluster name you want to delete.
        Default: $JENKINS_CLUSTER_NAME

  Example:
    $0 -p jenkins-project -c jenkins-poc
EOF
  exit 1
}

source ${ROOT}/common.sh

# Override JENKINS_PROJECT variable from properties file with -p flag
if [ ! -z "${PROJECT}" ]; then
  JENKINS_PROJECT=${PROJECT}
fi

# Switch to project
gcloud config set project ${JENKINS_PROJECT}

# verify which project your on
echo "Current project: $(gcloud config get-value project)"

# Get credentials for the k8s cluster
gcloud container clusters get-credentials ${JENKINS_CLUSTER_NAME} --zone \
  ${ZONE} --project ${JENKINS_PROJECT} --quiet

# Delete jenkins
echo "Deleting Jenkins"
kubectl -f manifests/ delete
# You have to wait the default pod grace period before you can delete the pvcs
echo "Sleeping 60 seconds before deleting PVCs. The default pod grace period."
sleep 60
# delete the pvcs
kubectl delete pvc -l app=jenkins

# Cleanup the cluster
echo "Deleting cluster"
gcloud container clusters delete ${JENKINS_CLUSTER_NAME} \
  --zone ${ZONE} --async  --quiet