#!/bin/bash -e

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

HALYARD_HOST=$1

# Provide required halyard host
if [ -z $HALYARD_HOST ]; then
  echo "Usage: portforward.sh [halyard-host]"
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

if [ ! -z "$CLUSTER_USER" ] && [ ! -z "$HALYARD_HOST" ] \
    && [ ! -z "$PROJECT" ]; then
  gcloud compute ssh "$CLUSTER_USER@$HALYARD_HOST" --project="$PROJECT" \
    --zone="$GKE_ZONE" --ssh-flag="-L 9000:localhost:9000" \
    --ssh-flag="-L 8084:localhost:8084"
  # Once logged in execute hal deploy connect
else
  echo "Failed to connect to $HALYARD_HOST"
fi