FROM php:8.1-apache

# set main params
ARG BUILD_ARGUMENT_ENV=dev
ENV ENV=$BUILD_ARGUMENT_ENV
ENV APP_HOME /var/www/html
ARG HOST_UID=1000
ARG HOST_GID=1000
ENV USERNAME=www-data
ARG INSIDE_DOCKER_CONTAINER=1
ENV INSIDE_DOCKER_CONTAINER=$INSIDE_DOCKER_CONTAINER

# check environment
#RUN if [ "$BUILD_ARGUMENT_ENV" = "default" ]; then echo "Set BUILD_ARGUMENT_ENV in docker build-args like --build-arg BUILD_ARGUMENT_ENV=dev" && exit 2; \
#    elif [ "$BUILD_ARGUMENT_ENV" = "dev" ]; then echo "Building development environment."; \
#    elif [ "$BUILD_ARGUMENT_ENV" = "test" ]; then echo "Building test environment."; \
#    elif [ "$BUILD_ARGUMENT_ENV" = "staging" ]; then echo "Building staging environment."; \
#    elif [ "$BUILD_ARGUMENT_ENV" = "prod" ]; then echo "Building production environment."; \
#    else echo "Set correct BUILD_ARGUMENT_ENV in docker build-args like --build-arg BUILD_ARGUMENT_ENV=dev. Available choices are dev,test,staging,prod." && exit 2; \
#    fi

# install all the dependencies and enable PHP modules
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
      procps \
      nano \
      git \
      unzip \
      libicu-dev \
      zlib1g-dev \
      libxml2 \
      libxml2-dev \
      libreadline-dev \
      supervisor \
      cron \
      sudo \
      libzip-dev \
      ssl-cert \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-configure intl \
    && docker-php-ext-install \
      pdo_mysql \
      sockets \
      intl \
      opcache \
      zip \
    && rm -rf /tmp/* \
    && rm -rf /var/list/apt/* \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# disable default site and delete all default files inside APP_HOME
RUN a2dissite 000-default.conf
RUN sudo make-ssl-cert generate-default-snakeoil --force-overwrite 
RUN rm -r $APP_HOME

# create document root, fix permissions for www-data user and change owner to www-data
RUN mkdir -p $APP_HOME/public && \
    mkdir -p /home/$USERNAME && chown $USERNAME:$USERNAME /home/$USERNAME \
    && usermod -o -u $HOST_UID $USERNAME -d /home/$USERNAME \
    && groupmod -o -g $HOST_GID $USERNAME \
    && chown -R ${USERNAME}:${USERNAME} $APP_HOME

# put apache and php config for Laravel, enable sites
COPY ./docker/general/laravel.conf /etc/apache2/sites-available/laravel.conf
COPY ./docker/general/laravel-ssl.conf /etc/apache2/sites-available/laravel-ssl.conf
RUN a2ensite laravel.conf && a2ensite laravel-ssl
COPY ./docker/$BUILD_ARGUMENT_ENV/php.ini /usr/local/etc/php/php.ini

# enable apache modules
RUN a2enmod rewrite
RUN a2enmod ssl

# install Xdebug in case development or test environment
#COPY ./docker/general/do_we_need_xdebug.sh /tmp/
#COPY ./docker/dev/xdebug.ini /tmp/
#RUN chmod u+x /tmp/do_we_need_xdebug.sh && /tmp/do_we_need_xdebug.sh

# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN chmod +x /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER 1

# add supervisor
RUN mkdir -p /var/log/supervisor
COPY --chown=root:root ./docker/general/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=root:crontab ./docker/general/cron /var/spool/cron/crontabs/root
RUN chmod 0600 /var/spool/cron/crontabs/root

# generate certificates
# TODO: change it and make additional logic for production environment
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem -subj "/C=AT/ST=Vienna/L=Vienna/O=Security/OU=Development/CN=example.com"

# set working directory
WORKDIR $APP_HOME



# copy source files and config file
COPY --chown=${USERNAME}:${USERNAME} . $APP_HOME/
COPY --chown=${USERNAME}:${USERNAME} .env $APP_HOME/.env

# install all PHP dependencies
#RUN if [ "$BUILD_ARGUMENT_ENV" = "dev" ] || [ "$BUILD_ARGUMENT_ENV" = "test" ]; then COMPOSER_MEMORY_LIMIT=-1 composer install --optimize-autoloader --no-interaction --no-progress; \
#    else COMPOSER_MEMORY_LIMIT=-1 composer install --optimize-autoloader --no-interaction --no-progress --no-dev; \
#    fi
# RUN composer update
# Install LaraAdmin

#RUN php composer.phar require kylekatarnls/update-helper laravel/laravel=5.2.31
#RUN composer create-project laravel/laravel=5.2.31 --no-install la1
#RUN cd /var/www/html/la1FROM php:8.1-apache



RUN composer require backpack/pagemanager
RUN composer require backpack/menucrud
RUN composer require backpack/settings
RUN composer require backpack/permissionmanager
RUN composer require backpack/backupmanager
RUN composer require pestopancake/laravel-backpack-database-notifications
#composer require soufiene-slimi/star-field-for-backpack
#RUN composer require soufiene-slimi/star-field-for-backpack:* -W
RUN composer config --no-plugins allow-plugins.kylekatarnls/update-helper true
RUN composer require backpack/crud -W
#RUN RUN composer require "dwij/laraadmin:1.0.40"
#RUN composer install --optimize-autoloader --no-interaction --no-progress --no-dev
#RUN composer create-project --no-install laravel/laravel=5.2.31 la1
#RUN composer require "dwij/laraadmin:1.0.40"
# install PHPMyadmin installer
# RUN git clone https://github.com/zevilz/phpMyAdminInstaller.git pma
#USER root
#RUN sh pma/pma_installer.sh -u root -g root
#RUN sudo chmod -R 777 storage/ bootstrap/ database/migrations/

USER ${USERNAME}
 
# Backpack + install a 3d party tool to generate migrations
# RUN composer require backpack/crud
# php artisan backpack:install
# RUN composer require --dev laracasts/generators
# RUN composer require --dev backpack/generators
#RUN php artisan backpack:install