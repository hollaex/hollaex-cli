FROM ubuntu:22.04

RUN apt-get update && apt-get install -y git curl sudo docker.io docker-compose

RUN curl --retry 3 --connect-timeout 10 -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.4/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN curl --retry 3 --connect-timeout 10 https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash

RUN curl --retry 3 --connect-timeout 10 https://raw.githubusercontent.com/bitholla/hollaex-cli/master/install.sh | bash

COPY docker/run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /root

ENTRYPOINT ["/run.sh"]