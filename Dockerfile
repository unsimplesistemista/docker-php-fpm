FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

ARG user=www-data
ARG php_version

ENV PHP_VERSION="${php_version:-7.2}"

# Install needed software
RUN apt-get update && apt-get -y install \
    python-software-properties \
    software-properties-common \
    language-pack-en-base \
    vim \
    supervisor \
    wget \
    curl \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

# Install nginx
RUN LANG=C.UTF-8 add-apt-repository -y ppa:ondrej/nginx-mainline && apt-get update && apt-get -y install \
    nginx \
    nginx-extras && \
    rm -rf /var/lib/apt/lists/*

# Install PHP packages
RUN LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php && apt-get update && apt-get -y install \
    php${PHP_VERSION} \
    php${PHP_VERSION}-apcu \
    php${PHP_VERSION}-apcu-bc \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-bz2 \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-dba \
    php${PHP_VERSION}-dev \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-gmp \
    php${PHP_VERSION}-igbinary \
    php${PHP_VERSION}-imagick \
    php${PHP_VERSION}-imap \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-memcached \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-mongodb \
    php${PHP_VERSION}-msgpack \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-ssh2 \
    php${PHP_VERSION}-tidy \
    php${PHP_VERSION}-xdebug \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-xsl \
    php${PHP_VERSION}-zip && \
    rm -rf /var/lib/apt/lists/*

# Install mcrypt
RUN if dpkg --compare-versions ${PHP_VERSION} lt 7.2; \
    then \
      apt-get -y install php${PHP_VERSION}-mcrypt && \
      rm -rf /var/lib/apt/lists/* && \
      phpenmod mcrypt; \
    fi

# Install PHP composer
RUN curl -sSL https://getcomposer.org/installer -o composer-setup.php && \
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
        rm composer-setup.php

# Install NewRelic
RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list && \
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - && \
    apt-get update && apt-get -y install newrelic-php5 && \
    rm -rf /var/lib/apt/lists/* && \
    phpdismod newrelic

# Disable nginx default sites
RUN rm /etc/nginx/sites-enabled/* \
    /etc/nginx/sites-available/*

ENV PHP_CFG_PATH="/etc/php/${PHP_VERSION}"
ENV PHP_ENV_FILE="/etc/php/environment" \
    PHP_FPM_CFG_FILE="${PHP_CFG_PATH}/fpm/php-fpm.conf" \
    PHP_FPM_POOL_CFG_FILE="${PHP_CFG_PATH}/fpm/pool.d/www.conf" \
    PHP_FPM_INI_FILE="${PHP_CFG_PATH}/fpm/php.ini" \
    PHP_CLI_INI_FILE="${PHP_CFG_PATH}/cli/php.ini"

ENV USER="${user}" \
    NGINX_WORKER_PROCESSES="4" \
    NGINX_WORKER_CONNECTIONS="65535" \
    NGINX_KEEPALIVE_TIMEOUT="0" \
    NGINX_CACHE_DIR="/dev/shm/nginx"

ENV PHP_DISPLAY_ERRORS="Off" \
    PHP_DEFAULT_CHARSET="ISO-8859-1" \
    PHP_MAX_EXECUTION_TIME="600s" \
    PHP_MEMORY_LIMIT="1024M" \
    PHP_POST_MAX_SIZE="16M" \
    PHP_UPLOAD_MAX_FILESIZE="50M" \
    PHP_DATE_TIMEZONE="Europe/Madrid" \
    PHP_XDEBUG_ENABLE="0" \
    PHP_XDEBUG_REMOTE_HOST="docker.for.mac.localhost" \
    PHP_XDEBUG_REMOTE_PORT="9000" \
    PHP_OPCACHE_ENABLE="1" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="65407" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="512"

ENV FPM_PROCESS_CONTROL_TIMEOUT="${PHP_MAX_EXECUTION_TIME}" \
    FPM_PM="ondemand" \
    FPM_PM_MAX_CHILDREN="250" \
    FPM_PM_START_SERVERS="5" \
    FPM_PM_MIN_SPARE_SERVERS="5" \
    FPM_PM_MAX_SPARE_SERVERS="10" \
    FPM_PM_PROCESS_IDLE_TIMEOUT="300s" \
    FPM_PM_MAX_REQUESTS="500"

ENV NEWRELIC_LICENSE="" \
    NEWRELIC_APPNAME="PHP Application"

RUN mkdir -p \
    /etc/nginx/ssl \
    /var/log/supervisor \
    /var/log/newrelic

ADD ./rootfs /
RUN chmod +x /usr/local/bin/*.sh && \
    chmod 644 /etc/cron.d/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
