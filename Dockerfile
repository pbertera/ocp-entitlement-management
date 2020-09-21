FROM registry.access.redhat.com/ubi8:latest

ADD https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 /bin/jq
ADD run.sh /run.sh
RUN dnf -y copr enable ocm/tools && dnf -y install ocm-cli && chmod +x /bin/jq

ENTRYPOINT ["/run.sh"]
