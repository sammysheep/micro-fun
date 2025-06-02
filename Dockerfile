# For building a minimal environment that includes R, BASH, and Perl while also
# supporting extraneous nextflow dependencies.


# For use with RHEL 8
FROM redhat/ubi8:latest AS builder1

SHELL ["/bin/bash", "-c"]



FROM redhat/ubi8:latest AS builder2

WORKDIR /micro

# Install all dependencies in /micro
RUN yum update \
    && yum install \
    --installroot /micro \
    --releasever 8 \
    --setopt install_weak_deps=false \
    --nodocs -y \
    grep gawk procps-ng sed perl gzip tar \
    which && yum clean all

RUN rm -rf /micro/lib64/python3.*

FROM redhat/ubi8-micro AS base

COPY --from=builder1 /usr/local /usr/local
COPY --from=builder2 /micro/etc/profile.d/which2.sh /micro/etc/profile.d/which2.csh /etc/profile.d/
COPY --from=builder2 /micro/usr/lib64 /usr/lib64
COPY --from=builder2 /micro/usr/share/perl5 /micro/usr/share/licenses /usr/share/

COPY --from=builder2 \
    /micro/bin/grep \
    /micro/bin/sed \
    /micro/bin/awk \
    /micro/bin/ps \
    /micro/bin/perl \
    /micro/bin/which \
    /micro/bin/zcat \
    /micro/bin/gzip \
    /micro/bin/tar \
    /bin/

WORKDIR /data
