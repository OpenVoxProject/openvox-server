FROM ruby:4.0-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless \
      rpm \
      leiningen \
    && rm -rf /var/lib/apt/lists/*

RUN git config --global user.email "openvox@voxpupuli.org" && \
    git config --global user.name "Vox Pupuli" && \
    git config --global --add safe.directory /code

CMD ["tail", "-f", "/dev/null"]
