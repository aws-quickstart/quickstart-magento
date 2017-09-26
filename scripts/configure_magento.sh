#!/bin/bash

if [ $# -ne 16 ]; then
    echo $0: usage: install_magento.sh dbhost dbuser dbpassword dbname cname adminfirstname adminlastname adminemail adminuser adminpassword cachehost magentourl protocol magentolanguage magentocurrency magentotimezone
    exit 1
fi

# cname = public name of the service (magento.javieros.tk)

dbhost=$1
dbuser=$2
dbpassword=$3
dbname=$4
cname=${5,,}
adminfirst=$6
adminlast=$7
adminemail=$8
adminuser=$9
adminpassword=${10}
cachehost=${11}
magentourl=${12}
protocol=${13}
magentolanguage=${14}
magentocurrency=${15}
magentotimezone=${16}

cd
#curl -o magento.tar.gz $magentourl
#echo "Running command aws s3 cp ${magentourl} magento.tar.gz"
#aws s3 cp $magentourl magento.tar.gz
#if [ $? -ne 0 ]; then
#    echo "Error downloading media from s3"
#    exit 1
#fi
[ -f "magento.tar.gz" ] && echo "Media file Found" || echo "Media file Not found"

cd /var/www/html
tar xzf ~/magento.tar.gz

find var vendor pub/static pub/media app/etc -type f -exec chmod g+w {} \;
find var vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} \;
chown -R :nginx .
chmod u+x bin/magento

cat << EOF > /var/www/html/pub/health
OK
EOF

if [ "$protocol" = "http" ]
then
  secure="--use-secure-admin=0 --use-secure=0"
else
  secure="--use-secure-admin=1 --use-secure=1 --base-url-secure=$protocol://$cname/"
fi

cd /var/www/html/bin
./magento setup:install --base-url=$protocol://$cname/ \
--db-host=$dbhost --db-name=$dbname --db-user=$dbuser --db-password=$dbpassword \
--admin-firstname=$adminfirst --admin-lastname=$adminlast --admin-email=$adminemail \
--admin-user=$adminuser --admin-password=$adminpassword --language=$magentolanguage \
--currency=$magentocurrency --timezone=$magentotimezone $secure

init_value=`head -n10 /var/www/html/app/etc/env.php`

cat << EOF > /var/www/html/app/etc/env.php
$init_value
  'session' =>
  array (
    'save' => 'redis',
    'redis' =>
      array (
        'host' => '$cachehost',
        'port' => '6379',
        'password' => '',
        'timeout' => '2.5',
        'persistent_identifier' => '',
        'database' => '0',
        'compression_threshold' => '2048',
        'compression_library' => 'gzip',
        'log_level' => '1',
        'max_concurrency' => '6',
        'break_after_frontend' => '5',
        'break_after_adminhtml' => '30',
        'first_lifetime' => '600',
        'bot_first_lifetime' => '60',
        'bot_lifetime' => '7200',
        'disable_locking' => '0',
        'min_lifetime' => '60',
        'max_lifetime' => '2592000',
    ),
  ),
  'cache' =>
  array(
     'frontend' =>
     array(
        'default' =>
        array(
           'backend' => 'Cm_Cache_Backend_Redis',
           'backend_options' =>
           array(
              'server' => '$cachehost',
              'port' => '6379',
              ),
      ),
      'page_cache' =>
      array(
        'backend' => 'Cm_Cache_Backend_Redis',
        'backend_options' =>
         array(
           'server' => '$cachehost',
           'port' => '6379',
           'database' => '1',
           'compress_data' => '0',
         ),
      ),
    ),
  ),
  'db' =>
  array (
    'table_prefix' => '',
    'connection' =>
    array (
      'default' =>
      array (
        'host' => '$dbhost',
        'dbname' => '$dbname',
        'username' => '$dbuser',
        'password' => '$dbpassword',
        'model' => 'mysql4',
        'engine' => 'innodb',
        'initStatements' => 'SET NAMES utf8;',
        'active' => '1',
      ),
    ),
  ),
  'resource' =>
  array (
    'default_setup' =>
    array (
      'connection' => 'default',
    ),
  ),
  'x-frame-options' => 'SAMEORIGIN',
  'MAGE_MODE' => 'production',
  'cache_types' =>
  array (
    'config' => 1,
    'layout' => 1,
    'block_html' => 1,
    'collections' => 1,
    'reflection' => 1,
    'db_ddl' => 1,
    'eav' => 1,
    'customer_notification' => 1,
    'full_page' => 1,
    'config_integration' => 1,
    'config_integration_api' => 1,
    'translate' => 1,
    'config_webservice' => 1,
    'compiled_config' => 1,
  ),
  'install' =>
  array (
    'date' => 'Tue, 19 Jul 2016 15:44:17 +0000',
  ),
);
EOF

mysql -h $dbhost -u $dbuser $dbname -p$dbpassword << EOF
INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'dev/static/sign', 1)
EOF

if [ "$protocol" = "http" ]
then

mysql -h $dbhost -u $dbuser $dbname -p$dbpassword << EOF
INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'web/url/redirect_to_base', 0)
EOF

fi

./magento deploy:mode:set production

./magento info:adminuri > /home/ec2-user/adminuri

