FROM ruby:4.0-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless \
      rpm \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein -O /usr/local/bin/lein && \
    chmod a+x /usr/local/bin/lein

RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

CMD ["tail", "-f", "/dev/null"]
