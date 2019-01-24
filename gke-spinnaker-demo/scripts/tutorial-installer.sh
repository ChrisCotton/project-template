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

# This script is the set of commands that get executed when you do the
# tutorial (README.md). It's a quick way to get a simple Spinnaker up and
# running.
#
# $1 is the project you're deploying to

PROJECT=$1
GKE_ZONE=us-west1-b
GKE_NAME=spinnaker
SPIN_SA=spinnaker-storage-account
HALYARD_SA=halyard-service-account
HALYARD_HOST=halyard-host
gcloud config set project $PROJECT
gcloud config set compute/zone $GKE_ZONE

gcloud services enable cloudapis.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable sourcerepo.googleapis.com

gcloud container clusters create $GKE_NAME \
  --machine-type=n1-standard-4

gcloud container clusters get-credentials $GKE_NAME

kubectl create serviceaccount spinnaker-service-account

kubectl create clusterrolebinding \
  --user system:serviceaccount:default:spinnaker-service-account \
  spinnaker-role \
  --clusterrole cluster-admin

kubectl create namespace spinnaker

SERVICE_ACCOUNT_TOKEN=$(kubectl get serviceaccounts spinnaker-service-account \
  -o jsonpath='{.secrets[0].name}')

kubectl get secret $SERVICE_ACCOUNT_TOKEN -o jsonpath='{.data.token}' | \
  base64 --d > ${GKE_NAME}_token.txt

gcloud iam service-accounts create $HALYARD_SA \
  --display-name $HALYARD_SA

HALYARD_SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:$HALYARD_SA" \
  --format='value(email)')

gcloud projects add-iam-policy-binding $PROJECT \
  --role roles/iam.serviceAccountKeyAdmin \
  --member serviceAccount:$HALYARD_SA_EMAIL

gcloud projects add-iam-policy-binding $PROJECT \
  --role roles/container.developer \
  --member serviceAccount:$HALYARD_SA_EMAIL

gcloud iam service-accounts create $SPIN_SA \
  --display-name $SPIN_SA

SPIN_SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:$SPIN_SA" \
  --format='value(email)')

gcloud projects add-iam-policy-binding $PROJECT \
  --role roles/storage.admin \
  --member serviceAccount:$SPIN_SA_EMAIL

gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SPIN_SA_EMAIL \
  --role roles/browser

gcloud compute instances create $HALYARD_HOST \
  --scopes=cloud-platform \
  --service-account=$HALYARD_SA_EMAIL \
  --image-project=ubuntu-os-cloud \
  --image-family=ubuntu-1404-lts \
  --machine-type=n1-standard-4

gcloud compute scp ./${GKE_NAME}_token.txt $HALYARD_HOST:~/
rm ./${GKE_NAME}_token.txt

##
# On to the Halyard VM
##

cat << 'EOF' > hal-setup.sh
set -o xtrace
PROJECT=$(gcloud config get-value project)
GKE_NAME=spinnaker
GKE_ZONE=us-west1-b
SPIN_SA=spinnaker-storage-account
SPIN_SA_DEST=~/.gcp/gcp.json
gcloud config set project $PROJECT
gcloud config set compute/zone $GKE_ZONE

KUBECTL_LATEST=$(curl -s \
  https://storage.googleapis.com/kubernetes-release/release/stable.txt)

curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_LATEST/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh
sudo bash -x InstallHalyard.sh --user $GKE_USER
. ~/.bashrc

mkdir -p $(dirname $SPIN_SA_DEST)

SPIN_SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:$SPIN_SA" \
  --format='value(email)')
  
gcloud iam service-accounts keys create $SPIN_SA_DEST \
  --iam-account $SPIN_SA_EMAIL

hal config version edit --version $(hal version latest -q)

hal config storage gcs edit \
  --project $(gcloud info --format='value(config.project)') \
  --json-path ~/.gcp/gcp.json

hal config storage edit --type gcs

hal config provider docker-registry enable

hal config provider docker-registry account add my-gcr-account \
  --address gcr.io \
  --password-file ~/.gcp/gcp.json \
  --username _json_key \
  --repositories $PROJECT/sample-app

gcloud container clusters get-credentials $GKE_NAME

kubectl config set-credentials $(kubectl config current-context) \
  --token $(cat ${GKE_NAME}_token.txt)

hal config provider kubernetes account add $GKE_NAME \
  --docker-registries my-gcr-account \
  --context $(kubectl config current-context)

hal config provider kubernetes enable

hal config deploy edit \
  --account-name $GKE_NAME \
  --type distributed

hal deploy apply
EOF

GKE_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | cut -d "@" -f 1)

gcloud compute scp ./hal-setup.sh $HALYARD_HOST:~/
rm ./hal-setup.sh

gcloud compute ssh $HALYARD_HOST --command "export GKE_USER=$GKE_USER && bash ~/hal-setup.sh"

##
# On to the sample app...
##

wget https://gke-spinnaker.storage.googleapis.com/sample-app.tgz \
  --no-check-certificate
tar xzfv sample-app.tgz
cd sample-app

git init
git add .
git commit -m "Initial commit"

gcloud source repos create sample-app
git config credential.helper gcloud.sh

git remote add origin \
  https://source.developers.google.com/p/$PROJECT/r/sample-app

git push origin master

cd ..

echo "DONE WITH TUTORIAL INSTALL"
