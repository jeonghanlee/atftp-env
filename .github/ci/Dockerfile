ARG ROCKY_VERSION=8.10
FROM rockylinux/rockylinux:${ROCKY_VERSION}

RUN dnf install -y git make sudo tree which autoconf automake gcc gcc-c++ \
        glibc-devel libtool flex binutils systemd bash /usr/bin/timeout gawk diffutils \
    && dnf clean all

COPY . /src
WORKDIR /src
RUN make init \
    && make build \
    && make install SYSTEMD_RELOAD=0 \
    && make service.check SYSTEMD_RELOAD=0 \
    && /opt/atftp/bin/atftp --version \
    && /opt/atftp/sbin/atftpd --version

ENV container=docker
CMD ["/sbin/init"]
