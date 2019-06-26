FROM ubuntu:18.04

RUN apt-get update && apt-get install -y git curl vim

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.13.4/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN curl -L https://git.io/get_helm.sh | bash

COPY . /root/hollaex-cli

RUN chmod +x /root/hollaex-cli && mv /root/hollaex-cli /root/.hollaex-cli && ln -s /root/.hollaex-cli/hollaex /usr/local/bin/hollaex && ex -sc '2i|SCRIPTPATH=/root/.hollaex-cli' -cx /root/.hollaex-cli/hollaex && ex -sc '2i|SCRIPTPATH=/root/.hollaex-cli' -cx /root/.hollaex-cli/config_form.sh

COPY docker/run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]