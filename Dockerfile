# -----------------------------------------------------------------------------
# docker-php
#
# Builds a basic docker image that can run PHP applications. This image is built
# with CI/CD in mind, but can be used as a base image for production or development
# environments.
#
# Author: Aranya Sen (https://github.com/senaranya)
# Require: Docker (http://www.docker.io/)
# -----------------------------------------------------------------------------

FROM php:8.0-apache-buster

LABEL name="php-ci-base" \
      version="1.0"  \
      maintainer="senaranya"

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    default-mysql-client \
    redis-server \
    libcurl4-gnutls-dev \
    libicu-dev \
    libmcrypt-dev \
    libxpm-dev \
    libxml2-dev \
    libbz2-dev \
    libzip-dev \
    libpq-dev \
    libaspell-dev \
    libpcre3-dev \
    libonig-dev \
    curl \
    wget \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Without this, redis doesn't start!
RUN echo exit 0 > /usr/sbin/policy-rc.d

# Install Nodejs, npm & Yarn
RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN apt update
RUN apt-get install -y nodejs yarn

# Install phpredis
RUN pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis

# Install php extensions
## pcov (for code coverage reports)
RUN apt-get update && apt-get install -y \
    autoconf \
    g++ \
    make \
    && pecl install -f pcov \
    && rm -rf /var/lib/apt/lists/*

RUN  docker-php-ext-enable pcov

RUN  docker-php-ext-install mbstring
RUN  docker-php-ext-install pdo_mysql
RUN  docker-php-ext-install intl
RUN  docker-php-ext-install zip
RUN  docker-php-ext-install bz2
RUN  docker-php-ext-install bcmath
RUN  docker-php-ext-install pcntl

# Install Composer
RUN  curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Apache configuration
RUN a2enmod rewrite ssl

# Make sure www-data works with umask as 002, else the directories/files created will not be readable/writable to itself
RUN file=/etc/apache2/envvars && \
    grep -q '^umask' $file && \
    sed -i 's/^umask.*/umask 002/' $file || echo 'umask 002' >> $file

# Install dockerize. Needed to make php container wait for services it depends on until they become available.
# Using wget instead of ADD command to utilize docker cache
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Allow www-data and sudo members to run commands as sudo without password
RUN sed -ie 's/%sudo   ALL=(ALL:ALL) ALL/%sudo	ALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers
RUN echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV DEBIAN_FRONTEND noninteractive
# Set the locale, to help Python and the user's applications deal with files that have non-ASCII characters
RUN apt-get update && apt-get install -y \
        locales

# Other useful tools
RUN apt-get update && apt-get install -y \
        vim \
        net-tools \
        redis-tools \
        iputils-ping

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN apt-get install -y gcc make curl debconf curl libcurl4-openssl-dev
RUN apt-get install -y git

RUN apt-get autoremove -y
RUN apt-get clean
