#!/bin/bash

[ "$DEBUG" == "1" ] && set -x && set +e

# Make it possible to execute preseed scripts
for script in `find /usr/local/bin/preseed/ -type f | sort 2>/dev/null`; do
  echo "=> Executing script ${script}"
  ${script}
done

# Disable xdebug
if [ ${PHP_XDEBUG_ENABLE} -ne 1 ]; then
  echo "=> Disabling xdebug ..."
  phpdismod xdebug
fi

# Disable opcache
if [ ${PHP_OPCACHE_ENABLE} -ne 1 ]; then
  echo "=> Disabling opcache ..."
  phpdismod opcache
fi

# Enable newrelic if needed
if [ a"${NEWRELIC_LICENSE}" != "a" ]; then
    echo "=> Enabling newrelic ..."
    phpenmod newrelic
fi

# Generate Self-signed SSL Certificate
if [ ! -e /etc/nginx/ssl/server.crt -a ! -e /etc/nginx/ssl/server.key ]; then
  echo "=> Generating Self-signed SSL Certificate ..."
  openssl req -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/server.key -x509 -days ${SSL_EXPIRATION_DAYS:-3650} -out /etc/nginx/ssl/server.crt -batch -subj "/C=${SSL_COUNTRY:-ES}/ST=${SSL_STATE:-CATALONIA}/O=${SSL_ORGANIZATION:-UNSIMPLESISTEMISTA.COM}/localityName=${SSL_LOCALITY:-BARCELONA}/commonName=${SSL_COMMON_NAME:-localhost}"
fi

if [ ! -e /etc/nginx/ssl/dhparam.pem ]; then
  echo "=> Generating DH parameters ..."
  openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparam.pem ${SSL_DHPARAM_BYTES:-2048}
fi

# Fix SSL Certificate permissions
find /etc/nginx/ssl -type d -exec chmod 700 {} \;
find /etc/nginx/ssl -type f -exec chmod 600 {} \;

# Enable nginx modules
for module in `find /etc/nginx/modules-available/ -type f -name "*.conf"`; do
  if [ ! -e /etc/nginx/modules-enabled/`basename ${module}` ]; then
    echo "=> Activating nginx module ${module} ... "
    ln -s ${site} /etc/nginx/modules-enabled/
  fi
done

# Enable nginx sites
for site in `find /etc/nginx/sites-available/ -type f`; do
  if [ ! -e /etc/nginx/sites-enabled/`basename ${site}` ]; then
    echo "=> Activating nginx site ${site} ... "
    ln -s ${site} /etc/nginx/sites-enabled/
  fi
done

# Create the nginx cache path
mkdir -p ${NGINX_CACHE_DIR}

# Replace nginx config
perl -p -i -e "s/worker_processes .*;/worker_processes ${NGINX_WORKER_PROCESSES};/g" /etc/nginx/nginx.conf
perl -p -i -e "s/worker_connections .*;/worker_connections ${NGINX_WORKER_CONNECTIONS};/g" /etc/nginx/nginx.conf
perl -p -i -e "s/keepalive_timeout .*;/keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT};/g" /etc/nginx/nginx.conf

# Update PHP-FPM Process Manager settings
#perl -i -p -e "s/^;?process_control_timeout ?=.*/process_control_timeout = ${PHP_PROCESS_CONTROL_TIMEOUT}/g" ${PHP_FPM_CFG_FILE}
case `echo ${FPM_PM} | tr '[:upper:]' '[:lower:]'` in
  dynamic)
    perl -p -i -e "s/^;?pm.process_idle_timeout ?=/;pm.process_idle_timeout =/g" ${PHP_FPM_POOL_CFG_FILE}
  ;;
  ondemand)
    perl -p -i -e "s/^;?pm.start_servers ?=/;pm.start_servers =/g" ${PHP_FPM_POOL_CFG_FILE}
    perl -p -i -e "s/^;?pm.min_spare_servers ?=/;pm.min_spare_servers =/g" ${PHP_FPM_POOL_CFG_FILE}
    perl -p -i -e "s/^;?pm.max_spare_servers ?=/;pm.max_spare_servers =/g" ${PHP_FPM_POOL_CFG_FILE}
  ;;
  static)
    perl -p -i -e "s/^;?pm.process_idle_timeout ?=/;pm.process_idle_timeout =/g" ${PHP_FPM_POOL_CFG_FILE}
  ;;
esac

# Expose APP Environment Variables to PHP-FPM
touch ${PHP_ENV_FILE}
chown ${USER} ${PHP_ENV_FILE}
chmod 400 ${PHP_ENV_FILE}
for envVar in `env | grep "^APP_"`; do
  envVarNAme=`echo ${envVar} | awk -F= '{print $1}'`
  envVarValue=`echo ${envVar} | awk -F= '{print $2}'`

  echo "=> Exposing environment variable ${envVarNAme} to PHP ..."
  echo "env[${envVarNAme}] = ${envVarValue}" >> ${PHP_ENV_FILE}
done

# Delete old pid files if exist
find /var/run/ -name "*.pid" -type f -delete

if echo $@ | wc -w | grep "^0$" >/dev/null; then
  exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf --nodaemon
else
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  exec "$@"
fi
