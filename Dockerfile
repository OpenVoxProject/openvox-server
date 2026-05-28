FROM almalinux:9

WORKDIR /

RUN dnf install -y --enablerepo=crb vim wget git rpm-build java-21-openjdk-devel libyaml-devel zlib zlib-devel gcc-c++ patch readline readline-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison sqlite-devel ruby rubygem-bundler
RUN dnf -y module enable ruby:4.0 && dnf -y module install ruby:4.0
RUN wget https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
RUN chmod a+x lein
RUN mv lein /usr/local/bin
RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

CMD ["tail", "-f", "/dev/null"]
