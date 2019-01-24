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
# "-  This script will build a Kubernetes cluster in GKE running Jenkins  -"
# "-                                                                      -"
# "------------------------------------------------------------------------"


set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE[0]}")
PROJECT=""

usage() {
  cat <<-EOF
  Usage: $0 [-p <project> -c <cluster>]

  This script will build a Kubernetes cluster in GKE running Jenkins

  Make sure you updated the variables in the jenkins.properties file

  Optional arguments:
    -p  Name of the GCP project you want to build the jenkins cluster in.
        Default: $JENKINS_PROJECT

    -c  Cluster name you want to create.
        Default: $JENKINS_CLUSTER_NAME

  Example:
    $0 -p jenkins-project -c jenkins-poc
EOF
  exit 1
}
# shellcheck source=scripts/common.sh
source "${ROOT}"/common.sh

# Override JENKINS_PROJECT variable from properties file with -p flag
if [ ! -z "${PROJECT}" ]; then
  JENKINS_PROJECT=${PROJECT}
fi

# Switch to project
gcloud config set project ${JENKINS_PROJECT}

echo "Enabling the Container API."
gcloud services enable container.googleapis.com

# verify which project your on
echo "Current project: $(gcloud config get-value project)"

# This line is just to eliminate a warning that GKE behavior will change in the
# future. If we just set the new behavior now it doesn't warn us
# We are using async again mainly for consistency
gcloud config set container/new_scopes_behavior true > /dev/null

GKE_EXIST=$(gcloud container clusters list --filter "${JENKINS_CLUSTER_NAME}")

if [[ -z "${GKE_EXIST}" ]] ; then
  # Create GKE clusters with access to Container Registry
  # and Cloud Source Repositories
  gcloud container clusters create "${JENKINS_CLUSTER_NAME}" \
    --region "${REGION}"  \
    --node-locations "${ZONE}" \
    --num-nodes 3 \
    --cluster-version "${GKE_VERSION}" \
    --machine-type=n1-standard-4 \
    --enable-autorepair \
    --scopes 	"https://www.googleapis.com/auth/source.read_write,https://www.googleapis.com/auth/projecthosting,https://www.googleapis.com/auth/cloud-platform"
else
  echo
  echo "Cluster ${JENKINS_CLUSTER_NAME} already exists"
fi

gcloud container clusters get-credentials "${JENKINS_CLUSTER_NAME}" \
   --region "${REGION}" --project="${JENKINS_PROJECT}"

# Confirm that you can see the nodes in the cluster
kubectl get nodes

# In GKE you need to run this to be able to set RBAC permissions
if kubectl get clusterrolebinding | grep cluster-admin-binding; then
  echo
  echo "cluster-admin-binding already exists"
else
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
fi

# Create Jenkins namespace
if kubectl get namespaces jenkins| grep jenkins; then
  echo
  echo "Jenkins namespace already exists"
else
  kubectl create namespace jenkins
fi

# Create self signed cert for our Ingress to the Jenkins frontend
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key \
  -out /tmp/tls.crt -subj "/CN=jenkins/O=jenkins"

# Save our cert as a secret in Kubernetes
if kubectl get secrets -n jenkins | grep tls; then
  echo
  echo "Secret tls already exists"
else
  kubectl create secret generic tls --from-file=/tmp/tls.crt \
    --from-file=/tmp/tls.key -n jenkins
fi

# Deploy Jenkins to the K8s cluster
kubectl -f manifests/ apply

# Wait to get the external ip from the ingress
external_ip=""
while [ -z ${external_ip} ]; do
    echo
    echo "Waiting for external ip from ingress"
    sleep 10
    external_ip=$(kubectl get ingress/jenkins -n jenkins \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done

# Show Jenkins url
GREEN='\033[0;32m'
echo -e "${GREEN} \\nIt might take a few minutes for the Google Load Balancer \
to pass healthchecks and make this ip available to take traffic"
echo -e "${GREEN} \\nAccess Jenkins using this url https://${external_ip}"
