# Test environment mimicking a CINECA Galileo100 login node (CentOS 8.3, non-root user, sshd).
FROM centos:8.3.2011

# CentOS 8 is EOL: point the repos to the vault
RUN sed -i -e 's/^mirrorlist/#mirrorlist/' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' \
           /etc/yum.repos.d/CentOS-*.repo \
    && dnf install -y openssh-server python3 git curl zip unzip tar gzip bzip2 which findutils procps-ng \
    && dnf clean all \
    && ssh-keygen -A

# USERNAME comes from inventory.local.yml (see Makefile); ACCOUNT is a fake CINECA project name
ARG USERNAME
ARG ACCOUNT=test_account
RUN test -n "$USERNAME" \
    && mkdir -p /g100/home/userexternal \
    && useradd -m -p '*' -s /bin/bash -d /g100/home/userexternal/$USERNAME $USERNAME \
    && mkdir -p /g100_work/$ACCOUNT /g100_scratch/userexternal/$USERNAME \
    && chown $USERNAME: /g100_work/$ACCOUNT /g100_scratch/userexternal/$USERNAME \
    && printf 'export WORK=/g100_work/%s\nexport CINECA_SCRATCH=/g100_scratch/userexternal/%s\n' \
        "$ACCOUNT" "$USERNAME" > /etc/profile.d/cineca.sh

COPY entrypoint.sh /entrypoint.sh
ENV USERNAME=$USERNAME
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
