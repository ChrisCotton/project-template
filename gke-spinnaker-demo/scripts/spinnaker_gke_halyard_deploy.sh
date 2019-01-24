#!/bin/bash

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

#The following configures a GKE cluster and creates the Halyard VM

#Ensure the following APIs are enabled
# - Google Cloud Storage
# - Google Identity and Access Management (IAM) API
# - Google Cloud Resource Manager API
# - Cloud Source Repositories API
# - Google Pub/Sub API
# - Kubernetes Engine API
# - Container Registry API

HALYARD_SCRIPT=setup_halyard_host

# Return random string length 5; used to randomize resource names
random_string () {
  od -vAn -N4 -tx < /dev/urandom \
    | sed -e 's/^[ \t]*//' \
    | sed -e 's/[[:space:]]*$//'
}

# Read properties file
PROPERTIES_FILE="$HOME/.gcp/spinnaker_gke_halyard.properties"
if [ -f "$PROPERTIES_FILE" ]; then
  echo "Loading $PROPERTIES_FILE"
  source "$PROPERTIES_FILE"
else
  echo "Properties file not found, please configure $PROPERTIES_FILE."
  echo "Usage: spinnaker-gke-halyard-deploy.sh"
  exit 1
fi

# Setup constructed variables
POSTFIX=$(random_string)
echo "Generated id: [${POSTFIX}]"
HALYARD_HOST=halyard-host-$POSTFIX
CLUSTER_NAME=$GKE_NAME-$POSTFIX
CLUSTER_RESOURCE=$RESOURCE_ROOT/$CLUSTER_NAME
SPIN_SA=spinnaker-sa-$POSTFIX
SPIN_SA_KEY=spinnaker-sa.json
HALYARD_SA=halyard-sa-$POSTFIX

# Create the Halyard vm to manage the spinnaker installation and other
# stack admin tasks
create_halyard_vm () {
  #Create Halyard VM
  echo "Launching halyard VM"
  gcloud compute instances create "$HALYARD_HOST" \
    --project="$PROJECT" \
    --zone="$GKE_ZONE" \
    --scopes=cloud-platform \
    --service-account="$1" \
    --image-project=ubuntu-os-cloud \
    --image-family=ubuntu-1404-lts \
    --machine-type=n1-standard-4
}

# Wait for halyard vm to come up based on the name provided
# timeout 10 tries
wait_for_halyard_vm () {
  VM_INFO=""
  COUNTER=0
  until [ "$VM_INFO" != "" ]; do
    VM_INFO=$(gcloud compute instances list --format text \
      --filter="name=$1" | grep "deviceName")
    if [ "$VM_INFO" != "" ]; then
      return 0
    fi
    if [ $COUNTER -gt 10 ]; then
      return 1
    fi
    COUNTER=$((COUNTER+1))
    sleep 2
  done
  return 1
}

# Get service account email pattern given a particular display name
get_sa_email () {
  SA_EMAIL=$(gcloud iam service-accounts list \
    --project="$PROJECT" \
    --filter="displayName:$1" \
    --format='value(email)')
  echo "$SA_EMAIL"
}

# Create the GKE cluster and configure kubernetes service account
create_gke_cluster () {
  # Cluster exists when its resources are created; please note
  # on error cases the clean script needs to be run.
  if [ -d "$CLUSTER_RESOURCE" ]; then
    return 1
  fi
  # Create cluster resource location folder
  CLUSTER_RESULT=0
  if [ ! -z "$GKE_NAME" ] && [ ! -z "$CLUSTER_RESOURCE" ]; then
    mkdir -p "$CLUSTER_RESOURCE"
    # Unset legacy auth
    gcloud config unset container/use_client_certificate
    CLUSTER_RESULT=$(gcloud container clusters create "$CLUSTER_NAME" \
      --cluster-version="$GKE_VERSION" --machine-type=n1-standard-2 \
      --zone "$GKE_ZONE" | grep "$CLUSTER_NAME")
    if [[ ! -z "$CLUSTER_RESULT" ]]; then
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --zone="$GKE_ZONE"

      kubectl create serviceaccount spinnaker-service-account

      #Give spinnaker access to the cluster
      kubectl create clusterrolebinding \
        --user system:serviceaccount:default:spinnaker-service-account \
        spinnaker-role --clusterrole cluster-admin

      #Only necessary if spinnaker will be deployed to this cluster
      kubectl create namespace spinnaker

      SERVICE_ACCOUNT_TOKEN=$(kubectl get serviceaccounts \
        spinnaker-service-account -o jsonpath='{.secrets[0].name}')

      # Get token and base64 decode it since all secrets are stored in base64 in
      # Kubernetes and store it for later use
      kubectl get secret "$SERVICE_ACCOUNT_TOKEN" -o jsonpath='{.data.token}' \
        | base64 --decode > "$CLUSTER_RESOURCE/${CLUSTER_NAME}_token.txt"
      #Change to proper cluster wait
      sleep 10
      return 0
    fi
  fi
  return 1
}

# Assign role bindings for a service account; takes a service account name and
# a list of roles
assign_role_bindings () {
  SA_EMAIL=$1
  shift
  for ROLE in $@; do
    echo "Assigning role $ROLE to $SA_EMAIL"
    gcloud projects add-iam-policy-binding "$PROJECT" \
      --member "serviceAccount:$SA_EMAIL" --role "$ROLE"
  done
}

# Setup halyard service account
create_halyard_service_account () {
  gcloud iam service-accounts create "$HALYARD_SA" \
    --project="$PROJECT" \
    --display-name "$HALYARD_SA"
  HALYARD_SA_EMAIL=$(get_sa_email "$HALYARD_SA")

  #Assign roles for Halyard
  assign_role_bindings "$HALYARD_SA_EMAIL" \
                       "roles/iam.serviceAccountKeyAdmin" \
                       "roles/container.developer"
}

# Setup spinnaker service account
create_spinnaker_service_account () {
  gcloud iam service-accounts create "$SPIN_SA" \
    --project="$PROJECT" \
    --display-name "$SPIN_SA"
  SPIN_SA_EMAIL=$(get_sa_email "$SPIN_SA")

  #Create GCP credentials file for Spinnaker configuration
  gcloud iam service-accounts keys create "$CLUSTER_RESOURCE/$SPIN_SA_KEY" \
    --iam-account "$SPIN_SA_EMAIL"

  #Assign roles for Spinnaker
  assign_role_bindings "$SPIN_SA_EMAIL" \
                       "roles/storage.admin" \
                       "roles/pubsub.admin" \
                       "roles/browser" \
                       "roles/iam.serviceAccountKeyAdmin" \
                       "roles/container.admin"
}

# Copy resources needed by halyard host
copy_resources () {
  # Sometimes the VM fails to receive the first file; retry.
  echo "Copying resources..."
  COPY_STATUS=0
  for RETRY in $(seq 1 5);
  do
    echo "Retrying: ${RETRY}"
    gcloud compute scp --zone "$GKE_ZONE" \
      "$CLUSTER_RESOURCE/$SPIN_SA_KEY" \
      "${HALYARD_HOST}:~/" && s=0 && break || s=$? && sleep 2
    COPY_STATUS=$?
  done
  if [[ "$COPY_STATUS" -eq 0 ]]; then
    gcloud compute scp --zone "$GKE_ZONE" \
      "$CLUSTER_RESOURCE/${CLUSTER_NAME}_token.txt" "${HALYARD_HOST}:~/"
    gcloud compute scp --zone "$GKE_ZONE" \
      "./${HALYARD_SCRIPT}.sh" "${HALYARD_HOST}:~/"
    gcloud compute scp --zone "$GKE_ZONE" \
      "$PROPERTIES_FILE" "${HALYARD_HOST}:~/"
  else
    echo "Failed to copy file, please retry the deploy."
  fi
}

# Launch halyard setup script
run_halyard () {
  echo "Run halyard host setup"
  if [ ! -z "$HALYARD_HOST" ] && [ ! -z "$GKE_ZONE" ]; then
    gcloud compute ssh "$HALYARD_HOST" --zone "$GKE_ZONE" \
      --command "chmod +x ~/${HALYARD_SCRIPT}.sh"
    gcloud compute ssh "$HALYARD_HOST" --zone "$GKE_ZONE" --command \
      "bash ~/${HALYARD_SCRIPT}.sh ${POSTFIX} 1>&2 > ~/${HALYARD_SCRIPT}.log"
    if [[ $? -eq 0 ]]; then
      echo "Halyard host is ready:"
      gcloud compute instances list --format text \
        --filter="name=${HALYARD_HOST}" \
        | grep "halyard-host" \
        | grep "name:" \
        | sed -e 's/[[:space:]]*$//'
    else
      echo "Failed to run halyard host setup."
    fi
  else
    echo "Missing required halyard host variables."
  fi
}

#GKE cluster setup and kubernetes config
create_gke_cluster
CLUSTER_RESULT=$?

#Halyard Setup
if [[ "$CLUSTER_RESULT" -eq 0 ]]; then
  #Create service account for Halyard VM
  create_halyard_service_account

  #Create the admin VM
  create_halyard_vm "$HALYARD_SA_EMAIL"

  #Create service account for GCS/GCR
  create_spinnaker_service_account

  #Wait for halyard vm to come up
  wait_for_halyard_vm "$HALYARD_HOST"
  HALYARD_VM_STATUS=$?

  #Perform halyard tasks
  if [[ "$HALYARD_VM_STATUS" -eq 0 ]]; then
    #Copy over the token that was created earlier to the Halyard VM
    copy_resources

    #Run halyard commands
    run_halyard
  else
    echo "Failed to run Halyard VM"
  fi
else
    echo "Failed to create cluster"
fi