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
# "-  This script builds the GKE cluster that we will be deploying our     -"
# "-  sample app to. Service accounts and permissions will also be created -"
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
  Usage: $0

  This script will set up a Service Account for jenkins-project, which
  is granted with IAM for triggering Container Builder.
  Make sure you updated the variables in the jenkins.properties file

  Example:
    $0
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

SA_NAME=jenkins-deploy-gcb

# Create GCP Jenkins service account
if gcloud iam service-accounts list --filter ${SA_NAME} | grep ${SA_NAME}; then
  echo
  echo "${SA_NAME} service account already exists"
else
  gcloud iam service-accounts create ${SA_NAME} --display-name=${SA_NAME}
fi

# Get Jenkins service account ID
SA_ID=$(gcloud iam service-accounts list \
  --format='value(email)' --filter=${SA_NAME})
echo
echo "Jenkins Service Account ID: ${SA_ID}"


# Create key for Jenkins service account
gcloud iam service-accounts keys create --iam-account ${SA_ID} ${SA_NAME}.json

# Give sa service account permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${JENKINS_PROJECT} \
 --role=roles/cloudbuild.builds.editor \
 --member=serviceAccount:${SA_ID}

# Give sa project viewer permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${JENKINS_PROJECT} \
 --role=roles/viewer \
 --member=serviceAccount:${SA_ID}

# Give sa storage.admin permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${JENKINS_PROJECT} \
  --role roles/storage.admin \
  --member serviceAccount:${SA_ID}

REGION=us-west1
# Get credentials and switch to the jenkins kubectl context
gcloud container clusters get-credentials ${JENKINS_CLUSTER_NAME} \
  --region=${REGION} --project=${JENKINS_PROJECT}

# Delete the secret from the Jenkins cluster if it already exists
if kubectl get secrets ${SA_NAME} -n jenkins | grep ${SA_NAME}; then
  echo
  echo "deleting the ${SA_NAME} secret since it already exists"
  kubectl delete secret ${SA_NAME} -n jenkins
fi

# Add the key to the Jenkins cluster as a secret
echo
echo "Adding the ${SA_NAME} secret to ${JENKINS_CLUSTER_NAME}"
kubectl create secret generic ${SA_NAME} --from-file=${SA_NAME}.json -n jenkins