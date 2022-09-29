# Raptoreum Smartnode April 2021

# Use Ubuntu 20 
FROM ubuntu:focal

LABEL maintainer="dk808"

# Install packages
RUN apt-get update && apt-get install --no-install-recommends -y \
  ca-certificates \
  wget \
  curl \
  jq \
  pwgen \
  nano \
  unzip \
  procps \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create dir to run datadir to bind for persistent data
RUN mkdir /raptoreum
VOLUME /raptoreum
WORKDIR /raptoreum

COPY ./bootstrap.sh ./rtm-bins.sh ./start.sh /usr/local/bin/
RUN chmod -R 755 /usr/local/bin
RUN rtm-bins.sh

# Smartnode p2p port
EXPOSE 10226

# Use healthcheck to deal with hanging issues and prevent pose bans
HEALTHCHECK --start-period=10m --interval=15m --retries=3 --timeout=10s \
  CMD healthcheck.sh

CMD start.sh
