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
    sudo \
    mysql-client \
    vim \
    supervisor \
    rsyslog \
    wget \
    curl \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

# Install postfix
ENV RELAY_HOST=email-smtp.eu-west-1.amazonaws.com:587 \
    RELAY_USERNAME=CHANGEME \
    RELAY_PASSWORD=CHANGEME \
    MY_NETWORKS="127.0.0.0/8" \
    MAILNAME=changeme.com \
    RATE_DELAY=1s 
RUN apt-get update && \
    echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections && \
    echo postfix postfix/mynetworks string "${MY_NETWORKS}" | debconf-set-selections && \
    echo postfix postfix/mailname string ${MAILNAME} | debconf-set-selections && \
    apt-get --yes --force-yes install mailutils postfix && \
    postconf -e mydestination="localhost.localdomain, localhost" && \
    postconf -e smtpd_banner='$myhostname ESMTP $mail_name' && \
    postconf -# myhostname && \
    postconf -e inet_protocols=ipv4 && \
    postconf -# smtp_fallback_relay && \
    postconf -e relayhost=${RELAY_HOST} && \
    postconf -e default_destination_rate_delay=${RATE_DELAY} && \
    postconf -e smtp_sasl_auth_enable=yes && \
    postconf -e smtp_sasl_security_options=noanonymous && \
    postconf -e smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd && \
    postconf -e smtp_use_tls=yes && \
    postconf -e smtp_tls_security_level=encrypt && \
    postconf -e smtp_tls_note_starttls_offer=yes && \
    postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt' && \
    echo "${RELAY_HOST} ${RELAY_USERNAME}:${RELAY_PASSWORD}" > /etc/postfix/sasl_passwd && \
    postmap hash:/etc/postfix/sasl_passwd && \
    chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db && \
    chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

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
      apt-get update && \
      apt-get -y install php${PHP_VERSION}-mcrypt && \
      rm -rf /var/lib/apt/lists/* && \
      phpenmod mcrypt; \
    fi

# Install PHP composer
RUN curl -sSLo composer-setup.php https://getcomposer.org/installer && \
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
    PHP_OPCACHE_REVALIDATE_FREQ="2" \
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
