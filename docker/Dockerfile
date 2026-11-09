# Test environment mimicking a CINECA Galileo100 login node (CentOS 8.3, non-root user, sshd).
FROM centos:8.3.2011

# CentOS 8 is EOL: point the repos to the vault
RUN sed -i -e 's/^mirrorlist/#mirrorlist/' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' \
           /etc/yum.repos.d/CentOS-*.repo \
    && dnf install -y openssh-server python3 git curl zip unzip tar gzip bzip2 which findutils procps-ng \
    && dnf clean all \
    && ssh-keygen -A

# ACCOUNT is only a build arg (not in the runtime env, as on G100); it is stored in ~/.ch_acc.def
# USERNAME comes from inventory.local.yml (see Makefile); ACCOUNT is a fake CINECA project name
ARG USERNAME
ARG ACCOUNT=test_account
RUN test -n "$USERNAME" \
    && mkdir -p /g100/home/userexternal \
    && groupadd -g 25200 interactive \
    && useradd -m -p '*' -g interactive -s /bin/bash -d /g100/home/userexternal/$USERNAME $USERNAME \
    && echo "$ACCOUNT" > /g100/home/userexternal/$USERNAME/.ch_acc.def \
    && chown $USERNAME: /g100/home/userexternal/$USERNAME/.ch_acc.def \
    && mkdir -p /g100_work/$ACCOUNT /g100_scratch/userexternal/$USERNAME /scratch_local \
    && chown $USERNAME: /g100_work/$ACCOUNT /g100_scratch/userexternal/$USERNAME \
    && chmod 770 /g100_work/$ACCOUNT /g100_scratch/userexternal/$USERNAME \
    && chmod 1777 /scratch_local \
    && printf 'export WORK=/g100_work/%s\nexport CINECA_SCRATCH=/g100_scratch/userexternal/%s\n[ "$(id -g)" = 25200 ] && export TMPDIR=/scratch_local\n' \
        "$ACCOUNT" "$USERNAME" > /etc/profile.d/cineca.sh

WORKDIR /g100/home/userexternal/$USERNAME

COPY entrypoint.sh /entrypoint.sh
ENV USERNAME=$USERNAME
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
