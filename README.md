# docker-lamp-stack
 Docker image with PHP, MySQL, Apache, Npm and Redis

# Details:
### This image contains following:
PHP with extensions: pcov, mbstring, curl, pdo_mysql, intl

Apache with modules: ssl, rewrite
  
MySQL
Redis
NPM
Yarn
Composer 2.0
git
vim
ping
redis client

# How to use:
#### For basic php applications:
```bash
docker 
```
A sample docker-compose file:
```yaml
```
A sample GitLab ci/cd config
```yaml
image: senaranya/php-mysql-apache:latest

# Check out: http://docs.gitlab.com/ee/ci/docker/using_docker_images.html#what-is-a-service
services:
  - mysql:latest
  - redis:latest

variables:
  MYSQL_HOST: mysql
  MYSQL_DATABASE: my_app_db
  MYSQL_USER: root
  MYSQL_ROOT_PASSWORD: secret
  REDIS_HOST: redis

stages:
  - build
  - static-analysis
  - test

# This folder is cached between builds
# http://docs.gitlab.com/ee/ci/yaml/README.html#cache
cache:
  paths:
    - vendor/
    - node_modules/

build:
  stage: build
  script:
    - cp .env.example .env

    - sed -i "s|APP_ENV=.*|APP_ENV=testing|" .env
    - sed -i "s|DB_HOST=.*|DB_HOST=$MYSQL_HOST|" .env
    - sed -i "s|DB_DATABASE=.*|DB_DATABASE=$MYSQL_DATABASE|" .env
    - sed -i "s|DB_USERNAME=.*|DB_USERNAME=$MYSQL_USER|" .env
    - sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$MYSQL_ROOT_PASSWORD|" .env
    - sed -i "s|REDIS_HOST=.*|REDIS_HOST=$REDIS_HOST|" .env
    - sed -i "s|REDIS_PORT=.*|REDIS_PORT=6379|" .env
    - sed -i "s|REDIS_CLIENT=.*|REDIS_CLIENT=phpredis|" .env
    - sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=file|" .env
    - sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=file|" .env
    - sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=sync|" .env
    - sed -i "s|TIMEZONE=.*|TIMEZONE=Europe/London|" .env

    - php artisan key:generate
    - php artisan config:cache
    - php artisan migrate
    - php artisan db:seed

    - cp .env .env.testing

  artifacts:
    paths:
      - .env
      - .env.testing
    expire_in: 1 day

phpcs:
  stage: static-analysis
  before_script:
    - cp .env.example .env
    - php -r "file_exists('phpcs.phar')?'':copy('https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar', 'phpcs.phar');"
  script:
    - php phpcs.phar --standard=PSR12 --error-severity=1 --warning-severity=1 --extensions=php app tests
  allow_failure: true

test:
  script:
    - php vendor/bin/phpunit --coverage-text --colors=never
```

#### For applications that need additional packages:
