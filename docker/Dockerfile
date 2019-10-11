FROM ubuntu:18.04

RUN apt-get update && apt-get install -y git curl sudo docker.io docker-compose

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.4/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN curl -L https://git.io/get_helm.sh | bash

RUN curl -L https://raw.githubusercontent.com/bitholla/hex-cli/master/install.sh | bash

COPY docker/run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /root

ENTRYPOINT ["/run.sh"]