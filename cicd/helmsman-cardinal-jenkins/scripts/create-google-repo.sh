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
# "-  This script creates a Repository in Cloud Source Repositories for   -"
# "_  the sample app and does an initial commit of the source             -"
# "-                                                                      -"
# "------------------------------------------------------------------------"

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE}")
PROJECT=""

usage() {
  cat <<-EOF
  Usage: $0 -d gitproject-location -n google-source-repo-name

  This script creates a Repository in Cloud Source Repositories for the sample
  app and does an initial commit of the source

  Make sure you updated the variables in the jenkins.properties file

  Optional arguments:
    -d  local directory of git project
    -n  google source repo name for the git project

  Example:
    $0 -d gitproject-location -n google-source-repo-name
EOF
  exit 1
}

source ${ROOT}/common.sh

# If REPO_DIR is not passed from the cmd line then fail
if [ -z "${REPO_DIR}" ]; then
    usage
fi

# If REPO_DIR is not passed from the cmd line then fail
if [ -z "${REPO_NAME}" ]; then
    usage
fi


# Switch to project
gcloud config set project ${JENKINS_PROJECT}

# verify which project your on
echo "Current project: $(gcloud config get-value project)"

cd ${REPO_DIR}

# Create repository in Cloud Source Repositories
if gcloud source repos list --filter ${REPO_NAME} | grep ${REPO_NAME}; then
  echo "${REPO_NAME} repository already exists"
else
  gcloud source repos create ${REPO_NAME}
fi

# Initialize the git repository
git init

# Run credential helper script
git config credential.helper gcloud.sh

# Set git remote
if git remote | grep google; then
  echo "git google already exists"
else
  git remote add google \
  https://source.developers.google.com/p/${JENKINS_PROJECT}/r/${REPO_NAME}
fi

# Add commit and push all files
git add .
git commit -m "Initial commit"
git push --all google