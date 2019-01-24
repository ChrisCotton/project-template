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

# TODO:
# This code is non-functional; checked in to capture how fiat is configured

# An administrator's email address
ADMIN=[user]@gflocks.com

# The downloaded service account credentials
# TODO: Find out which permissions need to be set
CREDENTIALS=gke-multi-container-service-[id].json

# Taken from the properties file
GKE_CLUSTER_NAME=shared-services-[id]
# Your organization's domain.
DOMAIN=gflocks.com

hal config security authz google edit \
  --admin-username $ADMIN \
  --credential-path $CREDENTIALS \
  --domain $DOMAIN

hal config security authz edit --type google

hal config security authz enable

GROUP=spinnaker # The new group membership

hal config provider kubernetes account edit $GKE_CLUSTER_NAME \
--required-group-membership $GROUP

hal deploy apply