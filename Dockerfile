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

FROM php:8.3-apache-bookworm AS build

LABEL name="php-ci-base" \
      maintainer="senaranya"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install --no-install-recommends -y \
    redis-tools \
    libcurl4-gnutls-dev \
    libicu-dev \
    libxml2-dev \
    libbz2-dev \
    libpq-dev \
    libaspell-dev \
    libpcre3-dev \
    libonig-dev \
    curl \
    wget \
    sudo \
    git \
    autoconf \
    g++ \
    make \
    gcc \
    debconf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The configure is meant for UploadedFile::fake()->image('<something>.jpg'..
RUN apt-get update && apt-get install --no-install-recommends -y \
    zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-install opcache sockets mbstring pdo_mysql intl bz2 bcmath pcntl && \
    pecl install redis pcov && docker-php-ext-enable redis pcov

RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# Install dockerize. Needed to make php container wait for services it depends on until they become available.
ENV DOCKERIZE_VERSION=v0.9.2
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Allow www-data and sudo members to run commands as sudo without password
RUN sed -ie 's/%sudo   ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers

RUN a2enmod rewrite ssl && \
    echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    # Make sure www-data works with umask as 002, else the directories/files created will not be readable/writable to itself
    sed -i '/^umask/ c\umask 002' /etc/apache2/envvars || echo 'umask 002' >> /etc/apache2/envvars

# FINAL STAGE (runtime only)
FROM php:8.3-apache-bookworm

# These extensions need runtime library to be available
RUN apt-get update && apt-get install --no-install-recommends -y \
    libzip-dev zlib1g-dev \
    libmagickwand-dev libmagickcore-dev imagemagick && \
    docker-php-ext-install zip && \
    pecl install imagick && docker-php-ext-enable imagick && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install --no-install-recommends -y \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /var/www/html /var/www/html
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer
COPY --from=build /usr/local/bin/dockerize /usr/local/bin/dockerize
COPY --from=build /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Without this, redis doesn't start...
RUN apt-get update && apt-get install --no-install-recommends -y \
    locales \ 
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen en_US.UTF-8 \
    && dpkg-reconfigure locales \
    && localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite ssl && \
    echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

