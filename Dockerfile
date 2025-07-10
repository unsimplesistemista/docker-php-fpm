ARG ARCH
ARG ubuntu_version
FROM ubuntu:${ubuntu_version:-22.04}

ENV DEBIAN_FRONTEND=noninteractive

ARG user=www-data
ARG php_version

ENV PHP_VERSION="${php_version:-7.2}"

# Fix GPG keys in apt...
#RUN apt-get update && apt-get -y install \
RUN apt-get --fix-broken -y install \
    slugify \
    gpg
ENV KEYS="871920D1991BC93C 4F4EA0AAE5267A6C B31B29E5548C16BF 32FA4C172DAD550E 71DAEAAB4AD4CAB6"
RUN for id in $KEYS; do \
      name=$(gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $id 2>&1 | grep -Eo '"[^"]+"' | xargs slugify); \
      gpg --export $id | tee /etc/apt/trusted.gpg.d/$name.gpg > /dev/null; \
    done

# Install needed software
RUN apt-get update && apt-get -y install \
    apt-transport-https \
    software-properties-common \
    language-pack-en-base \
    sudo \
    mysql-client \
    vim \
    supervisor \
    rsyslog \
    wget \
    curl \
    imagemagick \
    unzip && \
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
RUN LANG=C.UTF-8 add-apt-repository -y ppa:ondrej/nginx && apt-get update && apt-get -y install \
    nginx \
    nginx-extras && \
    rm -rf /var/lib/apt/lists/*

# Install PHP packages
RUN LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php && apt-get update && apt-get -y install \
    php${PHP_VERSION} \
    php${PHP_VERSION}-apcu --no-install-recommends \
    php${PHP_VERSION}-amqp \
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
    mkdir -p /run/php && \
    rm -rf /var/lib/apt/lists/*

# Install json
RUN if dpkg --compare-versions ${PHP_VERSION} lt 8.0; then \
      apt-get update && \
      apt-get -y install php${PHP_VERSION}-json && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# Install mcrypt
RUN if dpkg --compare-versions ${PHP_VERSION} lt 7.2; then \
      apt-get update && \
      apt-get -y install php${PHP_VERSION}-mcrypt && \
      rm -rf /var/lib/apt/lists/* && \
      phpenmod mcrypt; \
    fi

# Install apcu-bc
RUN if dpkg --compare-versions ${PHP_VERSION} ge 7.0 -a dpkg --compare-versions ${PHP_VERSION} lt 8.0 ; then \
      apt-get update && \
      apt-get -y install php${PHP_VERSION}-apcu-bc && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# Install PHP composer
RUN curl -sSLo composer-setup.php https://getcomposer.org/installer && \
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
        rm -f composer-setup.php

# Install NewRelic
RUN if uname -m | grep "^x86"; then \
  echo 'deb [signed-by=/usr/share/keyrings/download.newrelic.com-newrelic.gpg] http://apt.newrelic.com/debian/ newrelic non-free' | sudo tee /etc/apt/sources.list.d/newrelic.list && \
  wget -O- https://download.newrelic.com/548C16BF.gpg | sudo gpg --dearmor -o /usr/share/keyrings/download.newrelic.com-newrelic.gpg && \
  apt-get update && apt-get -y install newrelic-php5 && \
  rm -rf /var/lib/apt/lists/* && \
  phpdismod newrelic; \
fi

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
    PHP_MAX_INPUT_VARS="10000" \
    PHP_MAX_INPUT_TIME="600" \
    PHP_MAX_POST_TIME="600" \
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

# Install ioncube
ENV IONCUBE_LOADER_URL="http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz"
#RUN /usr/local/bin/install-ioncube.sh
RUN mkdir -p  /tmp/ioncube && \
    curl -sSL -o /tmp/ioncube/ioncube.tar.gz ${IONCUBE_LOADER_URL} && \
    cd /tmp/ioncube && \
    tar zxvf ioncube.tar.gz && \
    php_extension_dir=`php -i | grep "^extension_dir" | awk '{print $NF}'` && \
    php_ini_dir=`php -i | grep 'additional .ini files' | awk '{print $NF}'` && \
    cp /tmp/ioncube/ioncube/ioncube_loader_lin_${PHP_VERSION}.so ${php_extension_dir} && \
    echo "zend_extension = ${php_extension_dir}/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini && \
    echo "zend_extension = ${php_extension_dir}/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini && \
    rm -rf /tmp/ioncube

RUN mkdir -p \
    /etc/nginx/ssl \
    /var/log/supervisor \
    /var/log/newrelic && \
    rm -f /etc/localtime

ADD ./rootfs /
RUN chmod +x /usr/local/bin/*.sh && \
    chmod 644 /etc/cron.d/*

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
