Google has built the projects below as an educational resource for users and developers. Each project is a stand-alone exercise that demonstrates a small set of recommended practices for a specific problem space.

For more information, follow the links to each projects' readme.

**Disclaimer: These projects are not intended for production use.**

# Demonstration Projects by Concept
* [Databases](#databases)
  * [Stateful Applications (Cassandra)](#stateful-applications-cassandra)
  * [Cloud SQL](#cloud-sql)
* [Logging and Monitoring](#logging-and-monitoring)
  * [Monitoring with Stackdriver](#monitoring-with-stackdriver)
  * [Logging with Stackdriver](#logging-with-stackdriver)
  * [Tracing with Stackdriver](#tracing-with-stackdriver)
  * [Monitoring with Datadog](#monitoring-with-datadog)
* [Networking](#networking)
  * [Connect GCP Networks with VPC Peering](#connect-gcp-networks-with-vpc-peering)
  * [Connect GCP Networks with Cloud VPN](#connect-gcp-networks-with-cloud-vpn)
* [Rolling Upgrades](#rolling-upgrades)
  * [In Place Rolling Upgrade](#in-place-rolling-upgrade)
  * [Expand And Contract Upgrade](#expand-and-contract-upgrade)
  * [Blue/Green Upgrade](#bluegreen-upgrade)
* [Security](#security)
  * [Network Policies](#network-policies)
  * [Role Based Access Control (RBAC)](#role-based-access-control-rbac)
  * [Securing Containerized Applications](#securing-containerized-applications)
  * [Controlling Levels of Privilege](#controlling-levels-of-privilege)
* [Service Meshes](#service-meshes)
  * [Istio with Telemetry](#istio-with-telemetry)
  * [Istio with Mesh Expansion](#istio-with-mesh-expansion)
  * [Istio with Mesh Expansion Across Networks](#istio-with-mesh-expansion-across-networks)

## Databases

### Stateful Applications (Cassandra)

This project installs an Apache Cassandra database into a Kubernetes Engine cluster.
Various scripts are contained within this project that provide push button creation, validation, and deletion of the Cassandra(C*) database and Kubernetes Engine cluster.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-stateful-applications-demo)

### Cloud SQL

This project shows how easy it is to connect an application in Kubernetes Engine to a Cloud SQL instance, using the Cloud SQL Proxy container as a sidecar container.
You will deploy a Kubernetes Engine (Kubernetes Engine) cluster and a Cloud SQL Postgres instance, and use the Cloud SQL Proxy container to allow communication between them.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-cloud-sql-postgres-demo)

## Logging and Monitoring

### Monitoring with Stackdriver

This project walks you through setting up Monitoring and visualizing metrics from a Kubernetes Engine cluster.
The logs from the Kubernetes Engine cluster will be leveraged to walk through the monitoring capabilities of Stackdriver.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-monitoring-tutorial)


### Logging with Stackdriver

This project describes the steps required to deploy a sample application to Kubernetes Engine that forwards log events to Stackdriver Logging.
As a part of the exercise, you will create a Cloud Storage bucket and a BigQuery dataset for exporting log data.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-logging-sinks-demo)


### Tracing with Stackdriver

This project introduces you to Stackdriver's tracing feature, and provides a distributed tracing example that can serve as a basis for your own applications.
You will deploy a multi-tier application to a Kubernetes Engine cluster and trace calls between the components.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-tracing-demo)


### Monitoring with Datadog

This project demonstrates how a third party solution, like Datadog, can be used to monitor a Kubernetes Engine cluster and its workloads.
Using the provided manifest, you will install Datadog and a simple nginx workload into your cluster.
The Datadog agents will be configured to monitor the nginx workload, and ship metrics to your own Datadog account.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-datadog-demo)


## Networking

### Connect GCP Networks with VPC Peering

This project presents a number of best practices for establishing network links between Kubernetes Engine clusters, and exposing cluster services across Google Cloud projects.
You will use a set of Deployment Manager templates to create networks, subnets, and Kubernetes Engine clusters before running the provided connectivity validation script to your networks.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-networking-demos/tree/master/gke-to-gke-peering)


### Connect GCP Networks with Cloud VPN

This project shows how Kubernetes Engine clusters can be linked to applications running in an on-premise datacenter.
You will use a set of Deployment Manager templates to create Kubernetes clusters in different projects, and connect them with a Cloud VPN link.
Clusters in one project will be used as stand-ins for "on-premise" clusters, and the VPN will demonstrate remote communication between those clusters, and Kubernetes Engine clusters.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-networking-demos/tree/master/gke-to-gke-vpn)


## Rolling Upgrades

### In Place Rolling Upgrade

This project demonstrates a simple upgrade procedure that is best suited for clusters containing stateless workloads where little attention must be paid to, restarting and rescheduling application instances (pods).
You will perform the upgrade in two stages. First, the control plane is updated, then node pools are upgraded.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-rolling-updates-demo)


###  Expand And Contract Upgrade

This project shows how to use the ‘Expand and Contract’ pattern to upgrade a Kubernetes Engine cluster. The pattern is designed to avoid issues with resource availability in the course of a Kubernetes Engine upgrade.
The Expand and Contract Upgrade pattern increases both Node headroom, and Cluster headroom, by adding 1 or more new nodes to the node pool prior to starting the upgrade. Once the upgrade has completed, the extra nodes are removed.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-rolling-updates-demo/tree/master/expand-contract-upgrade/tree/master/in-place-rolling-upgrade)


###  Blue/Green Upgrade

This project demonstrates a Kubernetes Engine cluster upgrade using the blue/green, or "lift and shift" upgrade strategy. This upgrade strategy is a great choice for clusters containing mission-critical stateful apps that require extra care and attention during upgrades and migration.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-rolling-updates-demo/tree/master/blue-green-upgrade)

## Security

### Network Policies

This guide demonstrates how to improve the security of your Kubernetes Engine by applying fine-grained restrictions to network communication.
You will provision a simple HTTP server and two client pods in a Kubernetes Engine cluster, then use a Network Policy restrict connections from client pods.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-network-policy-demo)


### Role Based Access Control (RBAC)

This project covers two use cases for RBAC:
1. Assigning different permissions to user personas.
1. Granting limited API access to an application running within your cluster.
Since RBAC's flexibility can occasionally result in complex rules, you will also perform common steps for troubleshooting RBAC as a part of scenario 2.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-rbac-demo)


### Securing Containerized Applications

This project demonstrates a series of best practices for improving the security of containerized applications deployed to Kubernetes Engine.
You will deploy multiple instances of the same container image with a variety of security settings to illustrate the use of RBAC, security contexts, and AppArmor policies.  

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-application-security-demo)


### Controlling Levels of Privilege

This tutorial demonstrates how Kubernetes Engine security features can be used to grant varying levels of privilege to applications, based on their particular requirements.
You will use a combination of RBAC, network policies, security contexts, and AppArmor profiles to enforce appropriate security constraints on three distinct applications.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-security-scenarios-demo)


## Service Meshes

### Istio with Telemetry

This project demonstrates how to use an Istio service mesh in a single GKE cluster alongside Prometheus, Jaeger, and Grafana, to monitor cluster and workload performance metrics.
You will first deploy the Istio control plane, data plane, and additional visibility tools using the provided scripts, then explore the collected metrics and trace data in Grafana.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-istio-telemetry-demo)


### Istio with Mesh Expansion

In this project, you will leverage Kubernetes Engine and Google Compute Engine to explore how Istio can manage services that reside outside of the Kubernetes Engine environment.
You will deploy a typical Istio service mesh in Kubernetes Engine, then configure an externally deployed microservice to join the mesh.  

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-istio-gce-demo)


### Istio with Mesh Expansion Across Networks

This project demonstrates how Istio's mesh expansion feature can be used to link services accross a VPN. The feature allows for a non-Kubernetes service running outside of the Istio infrastructure on Kubernetes Engine, to be integrated into, and managed by the Istio service mesh.

[Go to the demo project](https://github.com/GoogleCloudPlatform/gke-istio-vpn-demo)
