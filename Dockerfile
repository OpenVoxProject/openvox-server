FROM almalinux:9

WORKDIR /

RUN dnf install -y --enablerepo=crb \
  autoconf \
  automake \
  bison \
  bzip2 \
  gcc-c++ \
  git \
  java-17-openjdk \
  libffi-devel \
  libtool \
  libyaml-devel \
  make \
  openssl-devel \
  patch \
  readline \
  readline-devel \
  rpm-build \
  sqlite-devel \
  wget \
  zlib \
  zlib-devel

# Extract SLES RPM macros to aid in the expansion of macros on SLES
# Isolate the target SUSE/SLES 15 systemd RPM macros to avoid EL10 host collision
RUN mkdir -p /opt/suse-rpm-macros && \
    wget -q https://download.opensuse.org/distribution/leap/15.6/repo/oss/noarch/systemd-rpm-macros-15-150000.7.39.1.noarch.rpm -O /tmp/suse-rpm-macros.rpm && \
    rpm2cpio /tmp/suse-rpm-macros.rpm | cpio -idmv -D /opt/suse-rpm-macros && \
    rm /tmp/suse-rpm-macros.rpm

ADD --chmod=0755 https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein /usr/local/bin/lein

RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

RUN wget -q https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer -O- | bash

RUN /bin/bash --login -c 'rbenv install 3.2.11' && \
    /bin/bash --login -c 'rbenv global 3.2.11'

CMD ["tail", "-f", "/dev/null"]
