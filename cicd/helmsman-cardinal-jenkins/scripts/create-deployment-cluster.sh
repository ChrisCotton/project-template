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
  Usage: $0 -e <environment>

  This script will build a Kubernetes cluster with a Service Account

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

# If user did not pass in -e flag then fail
if [ -z "${ENV}" ]; then
    usage
fi

# Check to make sure that what is passed with -e is a valid environment
if [[ ! "${VALID_ENV[@]}" =~ ${ENV} ]]; then
    echo
    echo "The environment: '${ENV}'' does not match allowed \
environments: ${VALID_ENV[*]}"
    echo
    usage
fi

# Generate values based on ENV
CLUSTER_NAME=${ENV}-poc
SA_NAME=jenkins-deploy-${ENV}-app

if [ "${ENV}" = "dev" ]; then
    PROJECT=${DEV_PROJECT}
fi

if [ "${ENV}" = "prod" ]; then
    PROJECT=${PROD_PROJECT}
fi

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

GKE_EXIST=$(gcloud container clusters list --filter ${CLUSTER_NAME})

if [ -z "${GKE_EXIST}" ] ; then
  #  Create GKE clusters
  gcloud container clusters create ${CLUSTER_NAME} \
    --cluster-version ${GKE_VERSION} \
    --num-nodes 3 \
    --enable-autorepair \
    --zone ${ZONE}   \
    --scopes  \
     "https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring"

else
  echo
  echo "Cluster ${CLUSTER_NAME} already exists"
fi

# Get credentials and switch to the Cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE} \
  --project=${PROJECT}

# Confirm you can see the nodes in the cluster
kubectl get nodes

# In GKE you need to run this to be able to set RBAC permissions
if kubectl get clusterrolebinding cluster-admin-binding; then
  echo
  echo "cluster-admin-binding already exists"
else
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin --user=$(gcloud config get-value account)
fi

# Create ENV namespace
if kubectl get namespaces | grep ${ENV}; then
  echo
  echo "${ENV} namespace already exists"
else
  kubectl create namespace ${ENV}
fi

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

# Give Jenkins service account permission to the GKE in the Jenkins project
gcloud projects add-iam-policy-binding ${PROJECT} \
 --role=roles/container.developer \
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
  --zone=${ZONE} --project=${JENKINS_PROJECT}

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