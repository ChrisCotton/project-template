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

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Common commands for all scripts                      -"
# "-                                                       -"
# "---------------------------------------------------------"

# gcloud and kubectl are required for this POC
command -v gcloud >/dev/null 2>&1 || { \
 echo >&2 "I require gcloud but it's not installed.  Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { \
 echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }

# Read properties file
ROOT=$(dirname "${BASH_SOURCE}")
PROPERTIES_FILE="${ROOT}/jenkins.properties"
if [ -f "${PROPERTIES_FILE}" ]
then
  echo "Loading ${PROPERTIES_FILE}"
  source "${PROPERTIES_FILE}"
else
  echo "Properties file not found."
  exit 1
fi

while getopts ":p:c:r:e:d:n:h;" opt; do
  case ${opt} in
    p) PROJECT=${OPTARG};;
    c) JENKINS_CLUSTER_NAME=${OPTARG};;
    e) ENV=${OPTARG};;
    d) REPO_DIR=${OPTARG};;
    n) REPO_NAME=${OPTARG};;
    h) usage;;
    \?)
      echo "Invalid flag on command line: ${OPTARG}" 1>&2
      ;;
    *) usage;;
  esac
done
shift $((OPTIND -1))

# If JENKINS_PROJECT not loaded from the jenkins.properites file then fail
if [ -z "${JENKINS_PROJECT}" ]; then
    usage
fi

# If JENKINS_CLUSTER_NAME not loaded from the jenkins.properites file then fail
if [ -z "${JENKINS_CLUSTER_NAME}" ]; then
    usage
fi

# If DEV_PROJECT not loaded from the jenkins.properites file then fail
if [ -z "${DEV_PROJECT}" ]; then
    usage
fi

# If PROD_PROJECT not loaded from the jenkins.properites file then fail
if [ -z "${PROD_PROJECT}" ]; then
    usage
fi

# Verify we have a default Zone set
if [ -z "${ZONE}" ]; then
    echo "gcloud cli must be configured with a default zone." 1>&2
    echo "run 'gcloud config set compute/zone ZONE'." 1>&2
    echo "replace 'ZONE' with the zone name like us-west1-a." 1>&2
    exit 1;
fi
