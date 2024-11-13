FROM almalinux:9

WORKDIR /

RUN dnf install -y --enablerepo=crb vim wget git rpm-build java-11-openjdk java-11-openjdk-devel libyaml-devel zlib zlib-devel gcc-c++ patch readline readline-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison sqlite-devel
RUN wget https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
RUN chmod a+x lein
RUN mv lein /usr/local/bin
RUN wget -q https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer -O- | bash
RUN /bin/bash --login -c 'rbenv install 3.2.5'
RUN /bin/bash --login -c 'rbenv global 3.2.5'
RUN git config --global user.email "contact@overlookinfratech.com"
RUN git config --global user.name "Overlook InfraTech"

CMD ["tail -f /dev/null"]