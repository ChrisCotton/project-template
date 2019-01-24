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

FROM jenkins/jnlp-slave

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
ENV TERRAFORM_VERSION 0.11.7
ENV GOLANG_VERSION 1.10.3
ENV GOLANG_ARCH linux-amd64
ENV GOLANG_SHA fa1b0e45d3b647c252f51f5e1204aba049cde4af177ef9f2181f43004f901035

USER root

RUN apt-get update && \
    apt-get install -y ca-certificates curl wget build-essential  \
    unzip git jq \
    # install shellcheck and flake8
    shellcheck flake8  &&\
    # install terraform
    wget -q -O /terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" &&\
    unzip /terraform.zip -d /bin &&\
    apt-get install -y jq \
      libapparmor-dev \
      libseccomp-dev
RUN curl https://sdk.cloud.google.com | bash && mv google-cloud-sdk /opt
RUN gcloud components install beta
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# install go
RUN set -eux; \
    url="https://golang.org/dl/go${GOLANG_VERSION}.${GOLANG_ARCH}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${GOLANG_SHA} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

# install hadolint
ADD hadolint /usr/local/bin/hadolint
RUN chmod 755 /usr/local/bin/hadolint
