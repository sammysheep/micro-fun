# For building a minimal environment that includes R, BASH, and Perl while also
# supporting extraneous nextflow dependencies.


# For use with RHEL 8
FROM redhat/ubi8:latest AS builder1

SHELL ["/bin/bash", "-c"]

RUN yum update \
    && yum install -y make gcc gcc-c++ gcc-gfortran perl diffutils \
    zlib-devel bzip2-devel xz-devel pcre2-devel libcurl-devel \
    wget


WORKDIR /buildr

RUN wget https://cran.r-project.org/src/base/R-4/R-4.5.0.tar.gz && tar -xzf R-4.5.0.tar.gz

WORKDIR /buildr/R-4.5.0

RUN ./configure --prefix=/usr/local --with-readline=no --with-x=no \
    --without-libdeflate-compression --without-recommended-packages --without-tcltk \
    --enable-java=no --enable-R-profiling=no --disable-openmp

RUN make -j 2 && make install

RUN if [[ -d "/usr/local/lib64/R" && ! -d "/usr/local/lib/R" ]];then \
    ln -s /usr/local/lib64/R /usr/local/lib/R; \
    fi

ENV libp=/usr/local/lib/R

RUN rm -rf $libp/library/*/{demo,help,html,doc} $libp/library/translations
RUN strip $libp/bin/exec/R
RUN mv $libp/doc/{AUTHORS,COPYRIGHTS} $libp/ && rm -rf $libp/doc

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
    libgfortran which && yum clean all

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
