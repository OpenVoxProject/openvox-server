FROM almalinux:9

WORKDIR /

RUN dnf install -y --enablerepo=crb vim wget git rpm-build java-17-openjdk java-17-openjdk-devel libyaml-devel zlib zlib-devel gcc-c++ patch readline readline-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison sqlite-devel
RUN wget https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
RUN chmod a+x lein
RUN mv lein /usr/local/bin
RUN wget -q https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer -O- | bash
# todo: it would be great if we could get the used ruby version from openvox-agent and use it here
# and maybe don't randomly download rbenv and leiningen
# and how bad is it that we hardcode java 11 above?
RUN /bin/bash --login -c 'rbenv install 3.2.9'
RUN /bin/bash --login -c 'rbenv global 3.2.9'
RUN git config --global user.email "openvox@voxpupuli.org"
RUN git config --global user.name "Vox Pupuli"
RUN git config --global --add safe.directory /code

CMD ["tail -f /dev/null"]
