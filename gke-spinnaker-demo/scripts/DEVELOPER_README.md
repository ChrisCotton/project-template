# Setup basic Spinnaker in Kubernetes Engine cluster

## Introduction

The scripts contained in the Spinnaker/scripts directory automates setup of
Spinnaker in a GCP Kubernetes Engine managed cluster. It uses bash to accomplish most tasks.
It is meant to provide a stable base installation for CICD POCs.

scripts:
```
spinnaker_gke_halyard_deploy.sh
spinnaker_gke_halyard_clean.sh
setup_halyard_host.sh
portforward.sh
```

resources:
```
~/.gcp/
spinnaker_gke_halyard.properties
```

For detailed description of each operation performed by the scripts above,
please refer to:

[README.md](../README.md)

## Architecture

For architecture description of each POC utilizing the spinnaker scripts in this
directory, please refer to:

[README.md](../README.md)

## Implementation

The script provides cluster creation, service account creation, role
assignment, bucket creation, and pub/sub topic creation and subscriptions.

The deploy script is executed on a local Mac/Linux development environment. The
script will setup GCP resources and configure Spinnaker using a halyard GCE
instance.

Resources created by the tool are appended by a random string used as an "id"
for the deployment.

```
[cluster-name]-[id]
```

## Prerequisites

Please install gcloud suite.

```
Google Cloud SDK - https://cloud.google.com/sdk/
```

Ensure the following APIs are enabled:
- Google Cloud Storage
```
gcloud services enable storage-component.googleapis.com
```
- Google Identity and Access Management (IAM) API
```
gcloud services enable iam.googleapis.com
```
- Google Cloud Resource Manager API
```
gcloud services enable cloudresourcemanager.googleapis.com
```
- Cloud Source Repositories API
```
gcloud services enable sourcerepo.googleapis.com
```
- Google Pub/Sub API
```
gcloud services enable pubsub.googleapis.com
```
- Kubernetes Engine API
```
gcloud services enable containers.googleapis.com
```
- Container Registry API
```
gcloud services enable containerregistry.googleapis.com
```

To get a complete list of installed APIs, run command:
```
gcloud services list
```

Please authenticate with GCP and set default project used in the properties
file:
```
gcloud auth login
gcloud config set project [PROJECT]
```

Sometimes quota problems are encountered, please check quotas if resource
allocation fails. Please see troubleshooting section for instructions on how to
increase the quota.

## Deployment

Deploy fresh installation of Spinnaker on Kubernetes Engine.
```
# If resources directory doesn't exist
$ mkdir ~/.gcp

# Change the values to the correct one for your project
$ cp spinnaker_gke_halyard.properties ~/.gcp/spinnaker_gke_halyard.properties

# Start the deployment
$ ./spinnaker_gke_halyard_deploy.sh
```

After, deployment completes take note of the halyard host name.
```
Halyard host is ready:
name: halyard-host-[id]
```

## Resources

The script creates the following resources:
```
- GKE Cluster (shared-services-[id])
- Bucket (spinnaker-data-[id])
- Service Accounts
    - Halyard SA (halyard-sa-[id])
    - Spinnaker SA (spinnaker-sa-[id])
- Pub/Sub Topic (topic-shared-services-[id])
- Pub/Sub Subscription (subs-shared-services-[id])
- Halyard VM (halyard-host-[id])
    - kubectl (Kubernetes cluster management tool)
    - roer (Used to configure Spinnaker pipeline templates;
      please see main [README.md](../README.md])
- Filesystem
    - Spinnaker SA Key (spinnaker-sa.json)
    - Token (shared-services-[id]_token.txt)
```

## Validation

In order to validate the installation make sure that the Spinnaker user
interface is accessible to the local environment and is functional.

Please make sure all deployment workloads show an "OK" status:
```
https://console.cloud.google.com/kubernetes/workload?
project=[PROJECT]&workload_list_tablesize=50
```

Kubernetes deployment status can also be viewed using kubectl command:
```
$ kubectl get pods --namespace=spinnaker
```

Once all pods are running, setup Spinnaker to be accessible to the local
environment:
```
# Connect to halyard host via ssh tunnel.
# The portforward script below sets up SSH tunnels to the halyard VM. For more
# information on port fowarding over SSH with compute instances please visit:
# https://cloud.google.com/solutions/connecting-securely
$ ./portforward.sh [HALYARD_HOST]

# Once connected to halyard-host please run:

# This will allow the Spinnaker ui to be accessible to your localhost browser
# environment.
# 1. Connect to Spinnaker container
# 2. Spinnaker service ports will be available
halyard-host-[id]$ hal deploy connect
+ Get current deployment
  Success
+ Connect to Spinnaker deployment.
  Success
Forwarding from 127.0.0.1:9000 -> 9000
Forwarding from [::1]:9000 -> 9000
Forwarding from 127.0.0.1:8084 -> 8084
Forwarding from [::1]:8084 -> 8084
Handling connection for 9000
Handling connection for 8084
Handling connection for 8084
Handling connection for 8084
```

Open browser and make sure Spinnaker ui appears.
```
http://localhost:9000
```

## Tear Down

Deleting the cluster and resources:
```
$ ls ~/.gcp

# Note the cluster id from above
# [cluster-name]-[id]
$ ./spinnnaker_gke_halyard_clean.sh [id]
```

If teardown fails, the resources described in the "Resources" section has to be
manually deleted.

## Troubleshooting

To troubleshoot halyard host installation:
```
# Login to halyard host in the GCP console and view the setup hal script log
# file.
$ cat setup_halyard_host.log
```

Quota problems:

Go to quota console and make sure there are no red markers under "Used" column.
Request a quota increase by selecting the maxed out resource and doing an
"Edit Quotas". Quota increases are all handled automatically by GCP but could
take some time to come into effect.
```
https://console.cloud.google.com/iam-admin/quotas?project=[PROJECT]
```

## Known issues

1. Spinnaker buckets spin-* does not get cleaned up.

2. If cleanup fails, manual cleanup of all resources must be performed.

3. InstallHalyard.sh outputs terminal errors that do not affect the
installation.
```
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
tput: unknown terminal "unknown"
gpg: keyring `/tmp/tmpj4k3a8gl/secring.gpg' created
gpg: keyring `/tmp/tmpj4k3a8gl/pubring.gpg' created
gpg: requesting key 86F44E2A from hkp server keyserver.ubuntu.com
gpg: /tmp/tmpj4k3a8gl/trustdb.gpg: trustdb created
gpg: key 86F44E2A: public key "Launchpad OpenJDK builds (all archs)" imported
gpg: Total number processed: 1
gpg:               imported: 1  (RSA: 1)
...
```

4. The following error is reported from GCP after service account is deleted
successfully. Double check if the service account is deleted successfully;
delete the service account manually if the command erroneously reported
the status.
```
Error from server (NotFound): serviceaccounts "spinnaker-sa-[id]" not found
```

## Authors

* **Arnold Cabreza** - *Initial repo*

## License

This project is licensed under the Apache License - see the
[LICENSE.md](../LICENSE.md) file for details
