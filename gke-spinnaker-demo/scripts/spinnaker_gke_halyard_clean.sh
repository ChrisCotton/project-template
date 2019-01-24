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

# The following cleans up resources created by the corresponding deploy script
# spinnaker_gke_halyard_deploy.sh

POSTFIX=$1

# Provide required id argument
if [ -z $POSTFIX ]; then
  echo "Usage: spinnaker_gke_halyard_clean.sh [id]"
  exit 1
fi

# Read properties file
PROPERTIES_FILE="$HOME/.gcp/spinnaker_gke_halyard.properties"
if [ -f "$PROPERTIES_FILE" ]; then
  echo "Loading $PROPERTIES_FILE"
  source "$PROPERTIES_FILE"
else
  echo "Properties file not found, please configure $PROPERTIES_FILE"
  exit 1
fi

# Setup constructed variables
HALYARD_HOST="halyard-host-$POSTFIX"
CLUSTER_NAME="$GKE_NAME-$POSTFIX"
CLUSTER_RESOURCE="$RESOURCE_ROOT/$CLUSTER_NAME"
HALYARD_SA="halyard-sa-$POSTFIX"
SPIN_SA="spinnaker-sa-$POSTFIX"

# Check for cluster resource directory; fail if it doesn't exists
echo "Checking cluster resource directory: [$CLUSTER_RESOURCE]"
if [ ! -d "$CLUSTER_RESOURCE" ]; then
  echo "Cluster resource directory doesn't exists, unable to clean "\
    "GCP resources."
  exit 1
fi

# Delete role bindings for a service account; takes service account name
# and a list of roles
delete_role_bindings () {
  SA_EMAIL=$1
  shift
  for ROLE in $@; do
    echo "Deleting role $ROLE from $SA_EMAIL"
    gcloud projects remove-iam-policy-binding "$PROJECT" \
      --member "serviceAccount:$SA_EMAIL" --role "$ROLE"
  done
}

# Delete the halyard service account deleting associated roles
delete_halyard_sa () {
  HALYARD_SA_EMAIL=$(gcloud iam service-accounts list \
    --project="$PROJECT" \
    --filter="displayName:$HALYARD_SA" \
    --format='value(email)')

  # Delete roles associated with the service account
  delete_role_bindings "$HALYARD_SA_EMAIL" \
                       "roles/iam.serviceAccountKeyAdmin" \
                       "roles/container.developer"

  echo "Deleting halyard service account ${HALYARD_SA_EMAIL}"
  #Delete service account for Halyard VM
  echo "Y" | gcloud iam service-accounts delete ${HALYARD_SA_EMAIL}
}

# Delete the spinnaker service account deleting associated roles
delete_spinnaker_sa () {
  SPIN_SA_EMAIL=$(gcloud iam service-accounts list \
    --project="$PROJECT" \
    --filter="displayName:$SPIN_SA" \
    --format='value(email)')

  # Delete roles associated with the service account
  delete_role_bindings "$SPIN_SA_EMAIL" \
                       "roles/storage.admin" \
                       "roles/pubsub.admin" \
                       "roles/container.admin" \
                       "roles/browser" \
                       "roles/iam.serviceAccountKeyAdmin"

  echo "Deleting Spinnaker service account ${SPIN_SA_EMAIL}"
  # Delete service account for GCS/GCR
  echo "Y" | gcloud iam service-accounts delete ${SPIN_SA_EMAIL}
}

# Delete the Halyard management VM
delete_halyard_vm () {
  # Delete Spinnaker access to the cluster
  kubectl delete clusterrolebinding spinnaker-role

  # Delete the service account in GKE
  kubectl delete serviceaccount "$SPIN_SA"

  # Delete Halyard VM
  echo "Deleting halyard VM"
  echo "Y" | gcloud compute instances delete "$HALYARD_HOST" \
    --project="$PROJECT" \
    --zone="$GKE_ZONE"
}

# Cleanup bucket
BUCKET="spinnaker-data-$POSTFIX"
gsutil -m rm -r "gs://${BUCKET}" || echo "Failed to delete bucket ${BUCKET}"

# Cleanup pubsub topics
TOPIC="topic-$CLUSTER_NAME"
SUBSCRIPTION="subs-$CLUSTER_NAME"

# Delete custom pubsub topic
delete_custom_topic () {
  echo "Deleting custom pub sub subscription:$SUBSCRIPTION topic:$TOPIC"
  gcloud pubsub subscriptions delete "$SUBSCRIPTION"
  gcloud pubsub topics delete "$TOPIC"
}

# Delete gcs notification and subscriptions
delete_gcs_topic () {
  echo "Deleting gcs pub sub subscription:$SUBSCRIPTION topic:$TOPIC"
  gcloud pubsub subscriptions delete "$SUBSCRIPTION"
  gsutil notification delete -t "$TOPIC"
  gcloud pubsub topics delete "$TOPIC"
}

# Delete gcr topic
delete_gcr_topic () {
  echo "Deleting gcr pub sub subscription:$SUBSCRIPTION project:$PROJECT"
  gcloud pubsub subscriptions delete "$SUBSCRIPTION"
  gcloud pubsub topics delete "projects/${PROJECT}/topics/gcr"
}

echo "Cleaning up $MSG_FORMAT"
# Select messaging format to use
case "$MSG_FORMAT" in
  "CUSTOM")
    delete_custom_topic
  ;;
  "GCS")
    delete_gcs_topic
  ;;
  "GCR")
    delete_gcr_topic
  ;;
  *)
    echo "Invalid message format argument."
    exit 1
esac

# Delete halyard service account
delete_halyard_sa

# Delete spinnaker service account
delete_spinnaker_sa

# Delete halyard vm and kubernetes service accounts
delete_halyard_vm

# Remove local cluster resources
if [ ! -z "$GKE_NAME" ]; then
  echo "Cleaning up resources..."
  rm -rf "$CLUSTER_RESOURCE"
fi

# Delete the cluster
echo "Y" | gcloud container clusters delete "$CLUSTER_NAME" --zone "$GKE_ZONE"
