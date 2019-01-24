This container images lives at `gcr.io/pso-helmsman-cicd/jenkins-k8s-node`

The image is similar to `gcr.io/cloud-solutions-images/jenkins-k8s-slave`

The difference is that this image is running a newer version of Google Cloud SDK
and the base image has been changed to `jenkins/jnlp-slave` since
`jenkinsci/jnlp-slave` is deprecated.