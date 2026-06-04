FROM almalinux:10

WORKDIR /

RUN dnf install -y --enablerepo=crb \
    autoconf \
    automake \
    bison \
    bzip2 \
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

ADD --chmod=0755 https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein

RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

CMD ["tail", "-f", "/dev/null"]
