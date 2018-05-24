# Base image
FROM php:5.6-apache
MAINTAINER Patryk Trochowski <patryk.trocho@gmail.com>

RUN echo 'Europe/Warsaw' > /etc/timezone

# --- SOFT --- #
RUN apt-get update 
RUN apt-get install -y \
    openssh-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libz-dev \
    libxml2-dev \
    libpng12-dev \
    zlib1g-dev \
    libssl-dev \
    libxrender-dev \
    python-setuptools \
    g++ \
    gdebi \
    libmemcached-dev \
    libcurl4-openssl-dev \
    imagemagick \
    libmagickwand-6.q16-dev --no-install-recommends \
    wget \
    sendmail \
    git \
    ruby \
    nodejs \
    npm

RUN ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.8.9/bin-Q16/MagickWand-config /usr/bin

RUN docker-php-ext-install -j$(nproc) iconv mcrypt && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install gd && \
    docker-php-ext-install opcache && \
    docker-php-ext-install zip && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install mbstring

RUN pecl channel-update pecl.php.net && \
    pecl install redis-2.2.8 && \
    pecl install mongo && \
    pecl install memcache && \
    pecl install memcached-2.2.0 && \
    pecl install xdebug && \
    pecl install imagick

RUN echo "extension=mongo.so" > /usr/local/etc/php/conf.d/ext-mongo.ini && \
    echo "extension=redis.so" > /usr/local/etc/php/conf.d/ext-redis.ini && \
    echo "extension=memcached.so" > /usr/local/etc/php/conf.d/ext-memcached.ini && \
    echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini && \
    echo "zend_extension=xdebug.so" > /usr/local/etc/php/conf.d/ext-xdebug.ini

# --- COMPOSER --- #
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Speed up Composer installations
RUN composer global require hirak/prestissimo

# Apache2 - Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# Apache2 mods
RUN a2enmod rewrite

# Install supervisor (using easy_install to get latest version and not from 2013 using apt-get)
RUN mkdir /var/log/supervisor/
RUN easy_install supervisor
RUN easy_install supervisor-stdout
ADD ./supervisor.conf /etc/supervisord.conf
RUN mkdir -p /etc/supervisor/
RUN mkdir -p /var/log/supervisor/

# Set up supervisor log and include extra configuration files
RUN sed -i -e "s#logfile=/tmp/supervisord.log ;#logfile=/var/log/supervisor/supervisord.log ;#g" /etc/supervisord.conf
RUN sed -i -e "s#;\[include\]#\[include\]#g" /etc/supervisord.conf
RUN sed -i -e "s#;files = relative/directory/\*.ini#files = /etc/supervisor/conf.d/\*.conf#g" /etc/supervisord.conf

# Install wkhtmltopdf
RUN wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz -O wkhtmltox.tar.xz && \
    tar xf wkhtmltox.tar.xz && \
    mv wkhtmltox/bin/* /usr/local/bin/ && \
    rm -Rf wkhtmltox*

# Initialization Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

EXPOSE 3306
EXPOSE 80
EXPOSE 9000

ENTRYPOINT ["/bin/bash"]
CMD ["/start.sh"]



