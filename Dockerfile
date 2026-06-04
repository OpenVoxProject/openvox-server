FROM almalinux:10

WORKDIR /

RUN dnf install -y --enablerepo=crb \
    autoconf \
    automake \
    bison \
    bzip2 \
    cpio \
    gcc-c++ \
    git \
    java-21-openjdk-devel \
    libffi-devel \
    libtool \
    libyaml-devel \
    make \
    openssl-devel \
    patch \
    readline \
    readline-devel \
    rpm-build \
    ruby \
    sqlite-devel \
    vim \
    wget \
    zlib \
    zlib-devel

# Extract SLES RPM macros to aid in the expansion of macros on SLES
RUN wget -q https://download.opensuse.org/distribution/leap/15.6/repo/oss/noarch/systemd-rpm-macros-15-150000.7.39.1.noarch.rpm -O /tmp/suse-macros.rpm && \
    rpm2cpio /tmp/suse-macros.rpm | cpio -idmv -D / && \
    rm /tmp/suse-macros.rpm

ADD --chmod=0755 https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein

RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

CMD ["tail", "-f", "/dev/null"]
