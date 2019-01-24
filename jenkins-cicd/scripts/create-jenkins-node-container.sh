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

# Build our Jenkins node image
source scripts/jenkins.properties
docker build -t gcr.io/$JENKINS_PROJECT/jenkins-k8s-node:1.0.0 jenkins-node-container

# To authenticate to the Container Registry, run the gcloud a Docker credential helper
gcloud auth configure-docker

# Push our image to the Container Registry in our Jenkins project
docker push gcr.io/$JENKINS_PROJECT/jenkins-k8s-node:1.0.0
