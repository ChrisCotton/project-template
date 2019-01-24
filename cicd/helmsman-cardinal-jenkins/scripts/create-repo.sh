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
  Usage: $0 [-p <project>]

  This script creates a Repository in Cloud Source Repositories for the sample
  app and does an initial commit of the source

  Make sure you updated the variables in the jenkins.properties file

  Optional arguments:
    -p  Name of the GCP jenkins project

  Example:
    $0 -p jenkins-project
EOF
  exit 1
}

source ${ROOT}/common.sh

# Switch to project
gcloud config set project ${JENKINS_PROJECT}

# verify which project your on
echo "Current project: $(gcloud config get-value project)"

cd sample-app

# Update the Jenkinsfile to replace the placeholder pso-examples with a
# reference to the Jenkins project
sed -i'' -e "s#pso-examples/jenkins#${JENKINS_PROJECT}/jenkins#" Jenkinsfile

# Replace the {{JENKINS_PROJECT}} placeholder in the jenkinsfile
sed -i'' -e "s#{{JENKINS_PROJECT}}#${JENKINS_PROJECT}#" Jenkinsfile

# Replace the {{DEV_PROJECT}} placeholder in the jenkinsfile
sed -i'' -e "s#{{DEV_PROJECT}}#${DEV_PROJECT}#" Jenkinsfile

# Replace the {{PROD_PROJECT}} placeholder in the jenkinsfile
sed -i'' -e "s#{{PROD_PROJECT}}#${PROD_PROJECT}#" Jenkinsfile

# Replace the {{ZONE}} placeholder in the jenkinsfile
sed -i'' -e "s#{{ZONE}}#${ZONE}#" Jenkinsfile

# Create repository in Cloud Source Repositories
if gcloud source repos list --filter sample-app | grep sample-app; then
  echo "sample-app repository already exists"
else
  gcloud source repos create sample-app
fi

# Initialize the git repository
git init

# Run credential helper script
git config credential.helper gcloud.sh

# Set git remote
if git remote | grep origin; then
  echo "git origin already exists"
else
  git remote add origin \
  https://source.developers.google.com/p/${JENKINS_PROJECT}/r/sample-app
fi

# Add commit and push all files
git add .
git commit -m "Initial commit"
git push origin master

# Create a development branch if it does not already exist
if git show-branch development; then
  git checkout development
else
  git checkout -b development
fi

git merge master
git push origin development

# Switch back to master
git checkout master
