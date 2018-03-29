# Base image
FROM php:7.1-apache

RUN echo 'Europe/Warsaw' > /etc/timezone
RUN a2enmod rewrite

# --- SOFT --- #
RUN apt-get update 
RUN apt-get install -y \
    openssh-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
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
    pecl install redis && \
    apt-get install -y libssl-dev && pecl install mongodb && \
    pecl install xdebug && \
    pecl install imagick

RUN echo "extension=mongodb.so" > /usr/local/etc/php/conf.d/ext-mongodb.ini && \
    echo "extension=redis.so" > /usr/local/etc/php/conf.d/ext-redis.ini && \
    echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini && \
    echo "zend_extension=xdebug.so" > /usr/local/etc/php/conf.d/ext-xdebug.ini

# Install memcache extension
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends unzip libpcre3 libpcre3-dev \
    && cd /tmp \
    && curl -sSL -o php7.zip https://github.com/websupport-sk/pecl-memcache/archive/php7.zip \
    && unzip php7 \
    && cd pecl-memcache-php7 \
    && /usr/local/bin/phpize \
    && ./configure --with-php-config=/usr/local/bin/php-config \
    && make \
    && make install \
    && echo "extension=memcache.so" > /usr/local/etc/php/conf.d/ext-memcache.ini \
    && rm -rf /tmp/pecl-memcache-php7 php7.zip

# Install memcached
RUN apt-get install -y libmemcached-dev \
  && git clone https://github.com/php-memcached-dev/php-memcached /usr/src/php/ext/memcached \
  && cd /usr/src/php/ext/memcached && git checkout -b php7 origin/php7 \
  && docker-php-ext-configure memcached \
  && docker-php-ext-install memcached


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

ENTRYPOINT ["/bin/bash"]
CMD ["/start.sh"]

