if [ -d /tmp/ioncube ]; then
  cd /tmp/ioncube && tar zxvf ioncube.tar.gz
  php_extension_dir=`php -i | grep extension_dir | awk '{print $NF}'`
  cp /tmp/ioncube/ioncube/ioncube_loader_lin_${STACK_VERSION}.so ${php_extension_dir}
  echo "zend_extension = ${php_extension_dir}/ioncube_loader_lin_${STACK_VERSION}.so" >> /etc/php5/fpm/conf.d/00-ioncube.ini
  echo "zend_extension = ${php_extension_dir}/ioncube_loader_lin_${STACK_VERSION}.so" >> /etc/php5/cli/conf.d/00-ioncube.ini
  rm -rf /tmp/ioncube
fi
