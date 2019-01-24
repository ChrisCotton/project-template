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
FROM jenkins/jnlp-slave:3.26-1

# TODO update before release
LABEL \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="Apache License 2.0" \
    org.label-schema.name="Jenkins JNLP Agent Docker image" \
    org.label-schema.url="https://hub.docker.com/r/jenkins/jnlp-slave/" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/jenkinsci/docker-jnlp-slave"

ENV CLOUDSDK_CORE_DISABLE_PROMPTS 1
ENV PATH /opt/google-cloud-sdk/bin:$PATH
ENV TERRAFORM_VERSION 0.11.8
ENV GOLANG_VERSION 1.11.1
ENV GOLANG_ARCH linux-amd64
ENV GOLANG_SHA 2871270d8ff0c8c69f161aaae42f9f28739855ff5c5204752a8d92a1c9f63993

USER root
# pipefail added for https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates=20161130+nmu1+deb9u1 curl=7.52.1-5+deb9u7 build-essential=12.3  \
    unzip=6.0-21 git=1:2.11.0-3+deb9u4 jq=1.5+dfsg-1.3 \
    # install shellcheck and flake8
    shellcheck=0.4.4-4 flake8=3.2.1-1  && \
    # install hadolint
    curl -s -o /usr/local/bin/hadolint -L https://github.com/hadolint/hadolint/releases/download/v1.13.0/hadolint-Linux-x86_64 && \
    chmod 755 /usr/local/bin/hadolint && \
    # install terraform
    curl -s -o /terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    unzip /terraform.zip -d /bin && \
    # install apparmor, seccomp
    apt-get install -y --no-install-recommends \
      libapparmor-dev=2.11.0-3+deb9u2 \
      libseccomp-dev=2.3.1-2.1 && \
    # install gcloud beta
    curl https://sdk.cloud.google.com | bash && mv google-cloud-sdk /opt && \
    gcloud components install beta && \
    # install kubectl
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    # install go
    url="https://storage.googleapis.com/golang/go${GOLANG_VERSION}.${GOLANG_ARCH}.tar.gz"; \
	curl -o go.tgz "$url"; \
	echo "${GOLANG_SHA} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	export PATH="/usr/local/go/bin:$PATH"; \
	go version && \
    # install and upgrade bazel
    # https://docs.bazel.build/versions/master/install-ubuntu.html
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    curl "https://bazel.build/bazel-release.pub.gpg" | apt-key add - && \
    apt-get update && \
    apt-get -y --no-install-recommends install openjdk-8-jdk=8u181-b13-1~deb9u1 bazel && \
    apt-get -y upgrade bazel && \
    # install parallel
    apt-get -y install parallel=20161222-1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER jenkins
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
ENV USER jenkins