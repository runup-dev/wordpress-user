##SET CLIENT

##SET VARIANT FROM PARAMETER
user=$1
domain=$2

## USER CHECK
if [ -z $user ]
then
 echo "PLESE INPUT USER"
 exit
fi

## DOMAIN CHECK
if [ -z $domain ]
then
 echo "PLESE INPUT DOMAIN"
 exit
fi

## USER CHECK
homeDir="/home/${user}"
if [ -d "${homeDir}" ]
then

  read -r -p "\"${user}\" is already go ahead? [Y/n] " input
  
  case $input in
    [yY][eE][sS]|[yY])
  ;;
    [nN][oO]|[nN])
  echo "Stop Shell Script"
  exit
       ;;
    *)
  echo "Invalid input..."
  exit 1
 ;;
 esac
fi


## CREATE USER
userdir=/home/$user
if [ ! -d "${userdir}" ]
then
  useradd $user
  chmod 755 /home/$user/
  chmod 755 /home/$user/www
fi

## SSH KEY GENERATE
if [ ! -f "/home/${user}/.ssh/authorized_keys" ]
then 

  #mkdir /home/${user}/.ssh
  #chown ${user}:${user} /home/${user}/.ssh
  #chmod 700 /home/${user}/.ssh
  ssh-keygen -t rsa -b 4096 -f /home/${user}/.ssh/id_rsa -P "Runup@)9070"
  touch /home/${user}/.ssh/authorized_keys
  chmod 600 /home/${user}/.ssh/authorized_keys
  cat /home/${user}/.ssh/id_rsa.pub > /home/${user}/.ssh/authorized_keys
  chown ${user}:${user} /home/${user}/.ssh/authorized_keys

fi

if [ -f "/home/${user}/.ssh/id_rsa.pub" -o -f "/home/${user}/.ssh/id_rsa" ] 
then

  read -r -p "keyFile Download Please [Y/n] " input

  case $input in
    [yY][eE][sS]|[yY])
       if [ -f "/home/${user}/.ssh/id_rsa.pub" ]
       then
         rm -f /home/${user}/.ssh/id_rsa.pub
       fi
       
       if [ -f "/home/${user}/.ssh/id_rsa" ]
       then 
         rm -f /home/${user}/.ssh/id_rsa
       fi
    ;;
    [nN][oO]|[nN])
       echo "Stop Shell Script"
       exit
    ;;
    *)
  echo "Invalid input..."
  exit 1
  ;;
 esac
fi


## CREATE QUAOTA
## TODO 


## CREATE DATABASE FILE
sql=/root/setClient.sql

var="CREATE DATABASE IF NOT EXISTS wp_${user};
CREATE USER IF NOT EXISTS ${user}_www@localhost;
SET PASSWORD FOR ${user}_www@localhost= PASSWORD(\"${user}@6951\");
GRANT ALL PRIVILEGES ON wp_${user}.* TO ${user}_www@localhost IDENTIFIED BY \"${user}@6951\";
FLUSH PRIVILEGES;"

## OVERWRITE SQL
if [ -f "$sql" ] 
then
  echo "$var" > "$sql";
fi

## CREATE PHP-FPM POOL
pool=/etc/php-fpm.d/${user}.conf

var="[${user}]
listen = /var/run/php-fpm/php-fpm-${user}.sock
user = ${user}
group = ${user}
listen.owner = nginx
listen.group = nginx
request_slowlog_timeout = 5s
slowlog = /var/log/php-fpm/slowlog-${user}.log
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 4
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 200
listen.backlog = -1
pm.status_path = /status
request_terminate_timeout = 120s
rlimit_files = 131072
rlimit_core = unlimited
catch_workers_output = yes
env[HOSTNAME] = \$HOSTNAME
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp"

echo "$var" > "$pool";

systemctl restart php-fpm 


## CREATE VHOST CONFIG
vhost=/etc/nginx/conf.d/${domain}.conf


if [ ${domain:0:3} == "www" ]
then

root_var="server {
    listen 80;
    server_name ${domain:4};
    return 301 \$scheme://${domain}\$request_uri;
}
"

fi



www_var="server {
    autoindex_localtime on;
    include rocket-nginx/default.conf;
    
    listen 80;
    server_name  ${domain};
    access_log   /var/log/nginx/${domain}.log;
    error_log    /var/log/nginx/${domain}.error.log;

    #  note that these lines are originally from the \"location /\" block
    root   /home/${user}/www/wordpress;
    #root /usr/share/nginx/html;    

    # wp address type
    location /{
        try_files \$uri \$uri/ /index.php?\$args;
    }

    #vhost_traffic_status_limit_traffic in:10M;
    #vhost_traffic_status_limit_traffic out:1M;

    error_page 404 /404.html;
    location = /404.html {
      root /usr/share/nginx/html;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
      root /usr/share/nginx/html;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php-fpm/php-fpm-${user}.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

}"


## OVERWRITE
if [ -n "${root_var}" ]
then
  echo "${root_var}${www_var}" > "$vhost";
else
  echo "$www_var" > "$vhost";
fi

## RESTART NGINX
systemctl restart nginx


## LETS ENCRYPT 
echo "LETS ENCRYPT"
if [ -n "${root_var}" ]
then
  /etc/letsencrypt/certbot-auto --nginx -d ${domain:4} -d ${domain}
else
  /etc/letsencrypt/certbot-auto --nginx -d ${domain}
fi


## INSTALL WORDPRESS
cd /home/${user}/www

if [ ! -f "/home/${user}/www/latest-ko_KR.tar.gz" ]
then
  wget https://ko.wordpress.org/latest-ko_KR.tar.gz
fi

tar -xzf /home/${user}/www/latest-ko_KR.tar.gz

## DATABASE IMPORT
echo "DATABASE IMPORT"
mysql -u root -p < /root/setClient.sql


## THEME INSTALL
unzip -o /usr/share/wp-library/astra.2.0.1.zip -d /home/${user}/www/wordpress/wp-content/themes
unzip -o /usr/share/wp-library/astra-child.zip -d /home/${user}/www/wordpress/wp-content/themes

## PLUGIN INSTALL
unzip -o /usr/share/wp-library/astra-addon-plugin-2.0.0.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/astra-portfolio-1.7.2.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/astra-premium-sites-1.3.19.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/ultimate-elementor-1.15.0.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/elementor.2.7.1.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/elementor-pro-2.6.2.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/admin-menu-editor-pro.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/ame-branding-add-on.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/wp-toolbar-editor.zip -d /home/[${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/wordpress-seo.11.8.zip -d /home/[${uesr}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/wp-rocket_3.3.6.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/envato-elements.1.1.3.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/iwp-client.zip -d /home/${user}/www/wordpress/wp-content/plugins
unzip -o /usr/share/wp-library/wordpress-seo.11.8.zip -d /home/${user}/www/wordpress/wp-content/plugins

chmod 2755 /home/${user}/www/wordpress
chown -R ${user}:${user} /home/${user}/www/wordpress
