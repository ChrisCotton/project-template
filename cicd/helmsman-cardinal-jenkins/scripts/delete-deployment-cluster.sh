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

# "-------------------------------------------------------------------------"
# "-                                                                       -"
# "-  This script removes the GKE cluster and service account              -"
# "-                                                                       -"
# "-------------------------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE}")
PROJECT=""
CLUSTER_NAME=""
ENV=""
VALID_ENV=""

usage() {
  cat <<-EOF
  Usage: $0 -e <environment>

  This script removes the GKE cluster and service account

  Make sure you updated the variables in the jenkins.properties file

  Required arguments:
    -e  Cluster Environment
        Valid values: ${VALID_ENV[*]}

  Example:
    $0 -e dev
EOF
  exit 1
}

source ${ROOT}/common.sh

# list of valid environments
VALID_ENV=(dev prod)

# Check to make sure what is passed with -e is a valid environment
if [[ ! "${VALID_ENV[@]}" =~ ${ENV} ]]; then
    echo
    echo "The environment: '${ENV}'' does not match allowed \
environments: ${VALID_ENV[*]}"
    echo
    usage
fi

# Generate values based on ENV
CLUSTER_NAME=${ENV}-poc
SA_NAME=jenkins-deploy-${ENV}

if [ "${ENV}" = "dev" ]; then
    PROJECT=${DEV_PROJECT}
fi

if [ "${ENV}" = "prod" ]; then
    PROJECT=${PROD_PROJECT}
fi

# If user did not pass in -e flag then fail
if [ -z "${ENV}" ]; then
    usage
fi

# Switch to project
gcloud config set project ${PROJECT}

# verify which project your on
echo "Current project: $(gcloud config get-value project)"


GKE_EXIST=$(gcloud container clusters list --filter ${CLUSTER_NAME})

if [ "${GKE_EXIST}" ] ; then
  # Get credentials for the k8s cluster
  gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE} \
    --project ${PROJECT} --quiet

  # Delete sample-app
  echo "Deleting sample-app"
  #kubectl -f sample-app/k8s/ delete -n ${ENV}

  # Cleanup the cluster
  echo
  echo "Deleting cluster"
  gcloud container clusters delete ${CLUSTER_NAME} \
    --zone ${ZONE} --async --quiet
fi

# Get Jenkins service account ID
SA_ID=$(gcloud iam service-accounts list \
  --format='value(email)' --filter=${SA_NAME})
echo
echo "Jenkins Service Account ID: ${SA_ID}"

# Remove service account from role
echo
echo "Removing ${SA_ID} from role"
gcloud projects remove-iam-policy-binding ${PROJECT} \
  --member serviceAccount:${SA_ID} --role roles/container.developer --quiet

# Delete the service account
echo
echo "Deleting service account: ${SA_ID}"
gcloud iam service-accounts delete ${SA_ID} --quiet

# Remove the Compute Engine default service account from the
# "Storage Object Viewer" role in the jenkins project
echo
echo "Removing default service account from role"
DEFAULT_SA_ID=$(gcloud iam service-accounts list \
  --format='value(email)' --filter='Compute Engine default service account')
gcloud projects add-iam-policy-binding ${JENKINS_PROJECT} \
  --role roles/storage.objectViewer \
  --member serviceAccount:${DEFAULT_SA_ID}

# Remove service account from all roles in the bucket
echo
echo "Removing bucket roles"
gsutil iam ch -d serviceAccount:${SA_ID} \
gs://artifacts.${JENKINS_PROJECT}.appspot.com

