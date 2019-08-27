FROM ubuntu:18.04

RUN apt-get update && apt-get install -y git curl vim

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.4/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN curl -L https://git.io/get_helm.sh | bash

COPY . /root/hex-cli

RUN chmod +x /root/hex-cli && mv /root/hex-cli /root/.hex-cli && ln -s /root/.hex-cli/hex /usr/local/bin/hex && ex -sc '2i|SCRIPTPATH=/root/.hex-cli' -cx /root/.hex-cli/hex && ex -sc '2i|SCRIPTPATH=/root/.hex-cli' -cx /root/.hex-cli/tools_generator.sh

COPY docker/run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]