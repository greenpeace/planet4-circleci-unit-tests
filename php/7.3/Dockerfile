FROM circleci/php:7.3

LABEL authors="Raymond Walker <raymond.walker@greenpeace.org>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# hadolint ignore=DL3008
RUN echo 'deb http://ftp.us.debian.org/debian sid main' | tee -a /etc/apt/sources.list && \
    curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install --no-install-recommends -y \
      build-essential \
      mysql-client-5.7 \
      nodejs \
      subversion \
      && \
    rm -rf /var/lib/apt/lists/* && \
    docker-php-ext-install mysqli

RUN npm install -g \
      stylelint@ \
      eslint@

USER circleci

ENV PATH="/home/circleci/.composer/vendor/bin:${PATH}"
