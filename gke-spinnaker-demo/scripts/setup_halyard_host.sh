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

#The following is to be run from within the Halyard VM
POSTFIX=$1

# Provide required id argument
if [ -z $POSTFIX ]; then
  echo "Usage: setup_halyard_host.sh [id]"
  exit 1
fi

# Read properties file
PROPERTIES_FILE="./spinnaker_gke_halyard.properties"
if [ -f "$PROPERTIES_FILE" ]
then
  echo "Loading $PROPERTIES_FILE"
  source "$PROPERTIES_FILE"
else
  echo "Properties file not found."
  exit 1
fi

# Setup constructed variables
SPIN_SA_KEY=spinnaker-sa.json
BUCKET="spinnaker-data-$POSTFIX"
CLUSTER_NAME="$GKE_NAME-$POSTFIX"
CLUSTER_TOKEN="${CLUSTER_NAME}_token.txt"
SPINNAKER_SA=$SPIN_SA_KEY
IMAGE_REGISTRY="$PROJECT/$APPLICATION_NAME"
TOPIC="topic-$CLUSTER_NAME"
SUBSCRIPTION="subs-$CLUSTER_NAME"
ROER_PACKAGE_BASE="https://github.com/spinnaker/roer/releases/download"
ROER_PACKAGE="$ROER_PACKAGE_BASE/$ROER_VERSION/$ROER_NAME"

# If some of the required files are missing, print error message
if [ ! -f "$SPINNAKER_SA" ] || [ ! -f "${CLUSTER_TOKEN}" ]; then
    echo "Service account error... exiting."
    exit 1
fi

# Get the current cluster user
get_cluster_user () {
  gcloud auth list --filter=status:ACTIVE \
    --format="value(account)" | cut -d "@" -f 1
}

# Install packages needed by the Halyard VM to manage
# the Spinnaker installation and the resources required
# to manage GKE clusters in Spinnaker.
install_vm_packages () {
  # Install kubectl for managing GCP project GKE clusters
  KUBECTL_LATEST=$(curl -s \
    https://storage.googleapis.com/kubernetes-release/release/stable.txt)
  KUBECTL_BASE="https://storage.googleapis.com/kubernetes-release/release"
  KUBECTL_BIN="$KUBECTL_BASE/$KUBECTL_LATEST/bin/linux/amd64/kubectl"
  echo "Download kubectl binary: $KUBECTL_BIN"
  curl -LO "$KUBECTL_BIN"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl

  # Install Halyard to manage the Spinnaker installation
  HALYARD_SCRIPT_BASE="https://raw.githubusercontent.com/spinnaker/halyard"
  echo "Download halyard script from base: $HALYARD_SCRIPT_BASE"
  curl -O "$HALYARD_SCRIPT_BASE/master/install/debian/InstallHalyard.sh"
  sudo bash InstallHalyard.sh -y --user "${CLUSTER_USER}"
  return $?
}

# Setup the Google Container Registry used by the Spinnaker installation
# The $IMAGE_REGISTRY is defined in the properties file and has to be manually
# uploaded to the Google Source Repository.
# Please see readme for the GCR setup ../README.md
setup_gcr_account () {
  GCR_ACCOUNT="gcr-$CLUSTER_NAME"

  #Configure GCR
  echo "Cofiguring GCR account $GCR_ACCOUNT registry with key \
    $SPINNAKER_SA and registry $IMAGE_REGISTRY"
  hal config provider docker-registry enable
  hal config provider docker-registry account add "$GCR_ACCOUNT" \
    --password-file "$SPINNAKER_SA" \
    --username _json_key \
    --address gcr.io \
    --repositories "$IMAGE_REGISTRY"
}

# Setup GKE provider in Spinnaker
# For more information on the v2 Kubernetes provider please visit:
# https://www.spinnaker.io/setup/install/providers/kubernetes-v2/
setup_gke_provider () {
  #Configure GKE Provider
  #The following will need to be executed for each cluster
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --project="$PROJECT" --zone "$GKE_ZONE"

  #Set credentials with the token that was created for Spinnaker
  CURRENT_CONTEXT=$(kubectl config current-context)

  kubectl config set-credentials "$CURRENT_CONTEXT" \
    --token "$(cat "$CLUSTER_TOKEN")"

  hal config provider kubernetes account add "$CLUSTER_NAME" \
    --docker-registries "$GCR_ACCOUNT" \
    --context "$(kubectl config current-context)" \
    --provider-version v2

  hal config provider kubernetes enable

  #Only needed if Halyard is to be installed on GKE
  hal config deploy edit \
    --account-name "$CLUSTER_NAME" \
    --type distributed
}

# Setup artifact account to be used by Spinnaker
# For more information on different artifacts supported please visit:
# https://www.spinnaker.io/reference/artifacts/
setup_artifact_account () {
  ARTIFACT_ACCOUNT_NAME="gcsaa-$CLUSTER_NAME"

  hal config features edit --artifacts true

  hal config artifact gcs account add "$ARTIFACT_ACCOUNT_NAME" \
    --json-path "$SPINNAKER_SA"

  hal config artifact gcs enable
}

# Setup GCP storage bucket used by Spinnaker
# The pipeline manifest deployment discussed in the main README.md uses the
# storage bucket to publish pipeline manifest.
# ../README.md
setup_bucket () {
  gcloud auth activate-service-account --key-file="$SPINNAKER_SA"

  gsutil mb -p "$PROJECT" "gs://${BUCKET}"

  #Configure GCS
  echo "Configuring GCS bucket with key $SPINNAKER_SA"
  hal config storage gcs edit \
    --project "$(gcloud info --format='value(config.project)')" \
    --json-path "$SPINNAKER_SA"
  hal config storage edit --type gcs
}

# Configure support for pipeline templates used by pipeline templates POC in
# the main README.md
# ../README.md
setup_pipeline_templates () {
  hal config features edit --pipeline-templates true
}

# Create custom pub/sub topic for the Spinnaker build triggers
# Sending your own pub/sub messages
create_custom_topic () {
  # First, record the fact that your $MESSAGE_FORMAT is CUSTOM, this will be
  # needed later.
  MESSAGE_FORMAT=CUSTOM

  # You need a topic with name $TOPIC to publish messages to:
  gcloud pubsub topics create "$TOPIC"

  # This topic needs a a pull subscription named $SUBSCRIPTION to let
  # Spinnaker read messages from. It is important that Spinnaker is the only
  # system reading from this single subscription. You can always create more
  # subscriptions for this topic if you want multiple systems to recieve the
  # same messages.
  gcloud pubsub subscriptions create "$SUBSCRIPTION" --topic "$TOPIC"
}

# Create GCS pub/sub topic for the Spinnaker build triggers
# Receiving messages from Google Cloud Storage (GCS)
create_gcs_topic () {
  # First, record the fact that your $MESSAGE_FORMAT is GCS, this will be
  # needed later.
  MESSAGE_FORMAT=GCS

  # Given that you’ll be listening to changes in a GCS bucket ($BUCKET),
  # the following command will create (or use an existing) topic with name
  # $TOPIC to publish messages to:
  gsutil notification create -t "$TOPIC" -f json "gs://${BUCKET}"

  # Finally, create a pull subscription named $SUBSCRIPTION to listen to
  # changes to this topic:
  gcloud pubsub subscriptions create "$SUBSCRIPTION" --topic "$TOPIC"
}

# Create GCR pub/sub topic for the Spinnaker build triggers
# Receiving messages from Google Container Registry (GCR)
create_gcr_topic () {
  # First, record the fact that your $MESSAGE_FORMAT is GCR, this will be
  # needed later.
  MESSAGE_FORMAT=GCR

  # Given a project name $PROJECT, GCR will always try to publish messages to
  # a topic named projects/${PROJECT}/topics/gcr for any repositories in
  # $PROJECT. To ensure that GCR has a valid topic to publish to, try to
  # create the following topic:
  gcloud pubsub topics create "projects/${PROJECT}/topics/gcr"

  # Finally, create a pull subscription named $SUBSCRIPTION to listen to
  # changes to this topic:
  gcloud pubsub subscriptions create "$SUBSCRIPTION" \
    --topic "projects/${PROJECT}/topics/gcr"
}

# Setup the pub sub entries for triggers
# Please see pub/sub trigger setup on Spinnaker for more detailed description:
# https://www.spinnaker.io/guides/user/triggers/pubsub/
setup_pub_sub () {
  # Select message format type
  case "$MSG_FORMAT" in
    "CUSTOM")
      create_custom_topic
    ;;
    "GCS")
      create_gcs_topic
    ;;
    "GCR")
      create_gcr_topic
    ;;
    *)
      echo "Invalid message format argument."
      exit 1
  esac

  # See 'A Pub/Sub Subscription' section above
  echo "Using message format: $MESSAGE_FORMAT"

  # You can pick this name, it's meant to be human-readable
  PUBSUB_NAME="pubsub-$CLUSTER_NAME"
  echo "Creating pubsub name: $PUBSUB_NAME"

  # First, make sure that Google Pub/Sub support is enabled:
  hal config pubsub google enable

  # Next, add your subscription
  hal config pubsub google subscription add "$PUBSUB_NAME" \
    --subscription-name "$SUBSCRIPTION" \
    --json-path "$SPINNAKER_SA" \
    --project "$PROJECT" \
    --message-format "$MESSAGE_FORMAT"
}

# Install roer tool for pipeline configuration
install_roer () {
  # Download ROER binary
  wget "$ROER_PACKAGE"
  # Make executable
  chmod +x "$ROER_NAME"
}

# Install packages needed by Halyard VM to manage Spinnaker installation
# and GKE clusters.
install_vm_packages
VM_PACKAGE_RESULT=$?

# Fail if required tools for Spinnaker management does not succeed
if [[ "$VM_PACKAGE_RESULT" -eq 0 ]];
then
  # Configure Spinnaker version to install
  hal config version edit --version "$(hal version latest -q)"

  # Setup GCR
  # GCR artifact account for the docker images
  setup_gcr_account

  # Configure GKE provider
  # Kubernetes support in GCP
  setup_gke_provider

  # Setup artifact account
  setup_artifact_account

  # Setup GCP bucket to use for the Spinnaker data
  # Target for Manifest files and other resources
  setup_bucket

  # Setup support for Pub Sub and configure topic/subscriptions
  # Pub/sub is setup on the bucket in order to trigger Spinnaker
  # pipelines
  setup_pub_sub

  # Setup support for templates
  # Pipeline templates allow pipelines to be defined using template
  # configuration file
  setup_pipeline_templates

  # Install ROER tool
  # https://github.com/spinnaker/roer
  install_roer
else
  echo "Failed to install required tools."
  exit 1
fi

# Deploy Spinnaker
hal deploy apply