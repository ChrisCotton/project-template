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

usage() {
  cat <<-EOF
  Usage: $0

  This script will build a Kubernetes cluster with a Service Account

  Make sure you updated the variables in the jenkins.properties file

  Required arguments:
     None

  Example:
    $0
EOF
  exit 1
}

source ${ROOT}/common.sh
# set REGION
REGION=us-west1

PROJECT=${DEV_PROJECT}
ENV="dev"

# Generate values based on ENV
SA_NAME=jenkins-deploy-${ENV}-infra

# Switch to project
gcloud config set project ${PROJECT}

# verify which project your on
echo "Current project: $(gcloud config get-value project)"

# Enable APIs
# Compute Engine API
gcloud services enable compute.googleapis.com
# Kubernetes Engine API
gcloud services enable container.googleapis.com

# This line is just to eliminate a warning that GKE behavior will change in the
# future. If we just set the new behavior now it doesn't warn us
# We are using async again mainly for consistency
gcloud config set container/new_scopes_behavior true > /dev/null

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

# Get Compute Engine default service account ID
DEFAULT_SA_ID=$(gcloud iam service-accounts list \
  --format='value(email)' --filter='Compute Engine default service account')
echo
echo "Compute Engine default service account ID: ${DEFAULT_SA_ID}"

# Create key for Jenkins service account
gcloud iam service-accounts keys create --iam-account ${SA_ID} ${SA_NAME}.json

# The command below needs to be run against the Jenkins project
echo
echo "Switching to the Jenkins project"
gcloud config set project ${JENKINS_PROJECT}

# verify which project your on
echo
echo "Current project: $(gcloud config get-value project)"

# Give Jenkins sa service account permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${PROJECT} \
 --role=roles/container.clusterAdmin \
 --member=serviceAccount:${SA_ID}

# Give Jenkins sa container.developer permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${PROJECT} \
 --role=roles/container.developer \
 --member=serviceAccount:${SA_ID}

# Give Jenkins sa roles.editor permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${PROJECT} \
 --role=roles/editor \
 --member=serviceAccount:${SA_ID}

# Give Jenkins roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding ${PROJECT} \
 --role=roles/iam.serviceAccountUser \
 --member=serviceAccount:${SA_ID}

# Give default GKE service account access to Container Registry in the
# Jenkins project (GKE access to registry)
gcloud projects add-iam-policy-binding ${JENKINS_PROJECT} \
  --role roles/storage.objectViewer \
  --member serviceAccount:${DEFAULT_SA_ID}

# Give Jenkins service account access to Container Registry bucket
# (container access to registry)
gsutil iam ch serviceAccount:${SA_ID}:objectCreator,admin \
  gs://artifacts.${JENKINS_PROJECT}.appspot.com

# Get credentials and switch to the jenkins kubectl context
gcloud container clusters get-credentials ${JENKINS_CLUSTER_NAME} \
  --region ${REGION} --project=${JENKINS_PROJECT}

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