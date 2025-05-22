FROM redhat/ubi8:latest AS builder

RUN yum update \
    && yum install \
    --installroot /micro \
    --releasever 8 \
    --setopt install_weak_deps=false \
    --nodocs -y \
    grep gawk procps-ng sed perl

FROM redhat/ubi8-micro AS base

WORKDIR /app
COPY --from=builder /micro/usr/lib64 /usr/lib64
COPY --from=builder /micro/usr/share/perl5 /usr/share/perl5
COPY --from=builder micro/bin/grep  /micro/bin/sed /micro/bin/awk /micro/bin/gawk /micro/bin/ps /micro/bin/perl /bin/

ENV PATH="/app:${PATH}"
WORKDIR /data
