
# Install R in /usr/local
# Customized and forked from: https://github.com/r-hub/r-minimal
# For use with RHEL 8
FROM redhat/ubi8:latest AS builder1

RUN yum update \
    && yum install -y wget gcc glibc-devel gcc-gfortran \
    gcc-c++ zlib-devel bzip2-devel xz-devel pcre-devel \
    pcre2-devel libcurl-devel make perl

ARG R_VERSION=4.5.0
ENV _R_SHLIB_STRIP_=true
WORKDIR /buildr

RUN yum install -y gcc glibc-devel gcc-gfortran gcc-c++ zlib-devel bzip2-devel xz-devel pcre-devel \
    pcre2-devel libcurl-devel make perl wget && \
    yum clean all

RUN wget https://cran.rstudio.com/src/base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz \
    && tar xzf R-${R_VERSION}.tar.gz

RUN cd R-${R_VERSION} \
    && ./configure \
    --prefix=/usr/local \
    --with-recommended-packages=no \
    --with-readline=no --with-x=no --enable-java=no \
    --enable-R-shlib \
    --disable-openmp --with-internal-tzcode \
    && make -j 4 \
    && make install

ENV libp=/usr/local/lib*/R

RUN strip -x $libp/bin/exec/R \
    && strip -x $libp/lib/* \
    && find $libp -name "*.so" -exec strip -x \{\} \;

RUN rm -rf $libp/library/translations \
    $libp/doc \
    && find $libp/library -name help | xargs rm -rf \
    && find $libp/share/zoneinfo/America/ -mindepth 1 -maxdepth 1 \
    '!' -name New_York  -exec rm -r '{}' ';' \
    && find $libp/share/zoneinfo/ -mindepth 1 -maxdepth 1 \
    '!' -name UTC '!' -name America '!' -name GMT -exec rm -r '{}' ';'

RUN sed -i 's/,//g' $libp/library/utils/iconvlist
RUN mkdir -p $libp/doc/html/ && touch $libp/doc/html/R.css

FROM redhat/ubi8:latest AS builder2

WORKDIR /micro

# Install all dependencies in /micro
RUN yum update \
    && yum install \
    --installroot /micro \
    --releasever 8 \
    --setopt install_weak_deps=false \
    --nodocs -y \
    grep gawk procps-ng sed perl \
    libgfortran xz-libs libcurl bzip2-libs pcre2 which

# Build Rust target
FROM redhat/ubi8:latest AS builder3

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN yum update -y && yum install -y zip git which gcc && yum clean all
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then  RUSTUP_SHA256="c64b33db2c6b9385817ec0e49a84bcfe018ed6e328fe755c3c809580cc70ce7a"; \
    elif [ "$ARCH" = "x86_64" ]; then RUSTUP_SHA256="a3339fb004c3d0bb9862ba0bce001861fe5cbde9c10d16591eb3f39ee6cd3e7f"; \
    else echo "Unsupported architecture: $ARCH" && exit 1; fi && \
    RUSTUP_URL="https://static.rust-lang.org/rustup/archive/1.28.1/${ARCH}-unknown-linux-gnu/rustup-init" && \
    curl --proto '=https' --tlsv1.2 -sSf -o rustup-init "$RUSTUP_URL" && \
    echo "${RUSTUP_SHA256} *rustup-init" | sha256sum -c - && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain nightly && \
    rm rustup-init && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME && rustc --version

SHELL ["/bin/bash", "-c"]
WORKDIR /app
ARG branch
COPY . .

RUN latest=$(git tag|tail -n1) \
    && git checkout ${branch:-$latest} \
    && cargo build --release \
    && cargo test

FROM redhat/ubi8-micro AS base
WORKDIR /app
COPY --from=builder1 /usr/local /usr/local
COPY --from=builder2 /micro/etc/profile.d/which2.sh /micro/etc/profile.d/which2.csh /etc/profile.d/
COPY --from=builder2 /micro/usr/lib64 /usr/lib64
COPY --from=builder2 /micro/usr/share/perl5 /usr/share/perl5
COPY --from=builder2 \
    /micro/bin/grep \
    /micro/bin/sed \
    /micro/bin/awk \
    /micro/bin/gawk \
    /micro/bin/ps \
    /micro/bin/perl \
    /micro/bin/which \
    /bin/

ARG name
ENV NAME=$name

COPY --from=builder3 \
    /app/target/release/$NAME \
    /app/Cargo.* \
    /app/LICENSE \
    /app/*.md \
    /app/


ENV PATH="/app:${PATH}"
WORKDIR /data
