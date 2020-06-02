# WORDPRESS USER CREATE
# Author : Runup. Kim Tae Oh


#############################
#SET VARIANT FROM PARAMETER
#############################
while getopts u:d:p: option 
do 
 case "${option}" 
 in 
 u) CREATE_USER=${OPTARG};; 
 d) DOMAIN=${OPTARG};; 
 p) PASSWD=${OPTARG};;
 esac 
done 
 

## USER CHECK
if [ -z $CREATE_USER ]
then
 echo "UserName is Required Option Name is -u"
 exit
fi

## DOMAIN CHECK
if [ -z $DOMAIN ]
then
 echo "Domain is Required Option Name is -d"
 exit
fi

## DOMAIN VALIDATION
if [ ${DOMAIN:0:4} == "http" -o ${DOMAIN:0:5} == "https" ]
then
  echo "Please Remove http or https Protocol"
  exit
fi

## USER EXISTS CHECK
USER_EXISTS=false
if [ $(getent passwd $CREATE_USER) ] ; then
	USER_EXISTS=true
fi


## SSL CHECK 
SSL_EXISTS=$(sudo [ -d "/etc/letsencrypt/live/${DOMAIN}/" ] && echo "true")
if [ -z ${SSL_EXISTS} ] ; then
	SSL_EXISTS=false
fi


###########################
# CREATE USER
###########################


## 유저생성 
if [ ! ${SSL_EXISTS} == "true" ] ; then
  sudo useradd $CREATE_USER
else
  echo "OVERWRITE CONFIRM"
fi


## MAKE DIRECTORY & PERMITION
sudo mkdir -p /home/${CREATE_USER}/www
sudo mkdir -p /home/${CREATE_USER}/www/wordpress
sudo chmod 755 /home/${CREATE_USER}
sudo chmod 755 /home/${CREATE_USER}/www
sudo chmod 755 /home/${CREATE_USER}/www/wordpress
sudo cp ./index.php.tmpl /home/${CREATE_USER}/www/wordpress/index.php
sudo chown -R ${CREATE_USER}:${CREATE_USER} /home/${CREATE_USER}
sudo chmod 644 /home/${CREATE_USER}/www/wordpress/index.php


## QUOTA 설정 
## TODO 
## 호스팅 용량 제한

## OPCACHE DISABLED WP-CONFIG
blacklist=/etc/php.d/opcache-default.blacklist
blacklist_tmp=opcache-default.blacklist
buffer="/home/${CREATE_USER}/www/wordpress/wp-config.php"
is_blacklist=$(cat ${blacklist} | grep ${buffer})

if [ -z $is_blacklist ] ; then
	sudo cp ${blacklist} ${blacklist_tmp}
	sudo chown $USER:$USER ${blacklist_tmp}
	sudo echo "$buffer" >> ${blacklist_tmp}
	sudo mv ${blacklist_tmp} ${blacklist}
	sudo chown root:root ${blacklist}
fi


########################### 
# CREATE DATABASE & GRANT 
###########################
echo "CREATE DATABASE"
buffer=`cat database.sql.tmpl`
buffer=${buffer//\[\[USER\]\]/${CREATE_USER}}
buffer=${buffer//\[\[PASSWD\]\]/${PASSWD}}
echo "$buffer" > "database.sql"
mysql -u root -p < database.sql
mv ./database.sql



###########################
# CREATE PHP-FPM
###########################
pool=/etc/php-fpm.d/${CREATE_USER}.conf
pool_tmp=${CREATE_USER}_pool.conf
rm -f ${pool_tmp}
buffer=`cat php-fpm-pool.conf.tmpl`
buffer=${buffer//\[\[USER\]\]/${CREATE_USER}}

## FILE WRITE
echo "${buffer}" > ${pool_tmp}

## MOVE
sudo mv ${pool_tmp} ${pool}
sudo chown root:root ${pool}
sudo systemctl restart php-fpm


############################
# CREATE NGINX-CONFIG
############################

vhost=/etc/nginx/conf.d/${DOMAIN}.conf
vhost_tmp=${CREATE_USER}_vhost.conf
rm -f ${vhost_tmp}

## ROOT DOMAIN CONFIG
if [ ${DOMAIN:0:3} == "www" ]
then
    buffer=`cat nginx-root-domain.conf.tmpl`
    buffer=${buffer//\[\[USER\]\]/${CREATE_USER}}
    buffer=${buffer//\[\[DOMAIN\]\]/${DOMAIN}}

    ## ADD SSL
    if [ ${SSL_EXISTS} == "true" ] ; then
	echo "ADD SSL"
    fi
fi

## WWW DOMAIN CONFIG 
buffer=`cat nginx-www-domain.conf.tmpl`
buffer=${buffer//\[\[USER\]\]/${CREATE_USER}}
buffer=${buffer//\[\[DOMAIN\]\]/${DOMAIN}}


## ADD SSL
if [ ${SSL_EXISTS} == "true" ] ; then
ssl_script="

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
";

redirect_script="
server {
    if (\$host = ${DOMAIN}) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot


    listen 80;
    server_name  ${DOMAIN};
    return 404; # managed by Certbot

}
"

buffer=${buffer//\[\[SSL\]\]/${ssl_script}}
buffer="${buffer} ${redirect_script}"

else
buffer=${buffer//\[\[SSL\]\]/}
fi



## FILE WRITE
echo "${buffer}" > ${vhost_tmp}

## MOVE
sudo mv ${vhost_tmp} ${vhost}
sudo chown root:root ${vhost}
sudo systemctl restart nginx


###########################
# CREATE LET'S ENCRYPT
###########################


if [ ! ${SSL_EXISTS} == "true" ] ; then
	echo "LETS ENCRYPT"
	if [ -n "${root_var}" ]
	then
	  sudo certbot-auto --nginx -d ${DOMAIN:4} -d ${DOMAIN}
	else
	  sudo certbot-auto --nginx -d ${DOMAIN}
	fi

fi

###########################
# TEST WEB CONNECT
###########################

echo "######################"
echo "Website Connect Result"
echo "######################"

curl -i https://${DOMAIN}

###########################
# CREATE PRIVATE KEY
###########################

ssh-keygen -t rsa -b 4096 -f /tmp/${CREATE_USER} -P ${PASSWD}
sudo mkdir -p /home/${CREATE_USER}/.ssh
sudo chmod 700 /home/${CREATE_USER}/.ssh
sudo mv /tmp/${CREATE_USER}.pub /home/${CREATE_USER}/.ssh/authorized_keys
sudo chmod 600 /home/${CREATE_USER}/.ssh/authorized_keys
sudo chown -R ${CREATE_USER}:${CREATE_USER} /home/${CREATE_USER}/.ssh

# DOWNLOAD CONFIRM
ip=$(sudo hostname -I | sed -e 's/^ *//g' -e 's/ *$//g')
echo "scp -i {Super User Key Location} ${USER}@${ip}:/tmp/${CREATE_USER} {Your Location}"
echo "DOWNLOAD PRIVATE KEY ?"

while :
do
read -rp "Y or N) " cf
case $cf in
        [yY])
                rm /tmp/${CREATE_USER}
                echo "Good!! please login ${CREATE_USER} And Setup"
                break
        ;;

        [nN])
                echo "exit"
                exit
        ;;

        *)
                echo "Please Input Yes or No !!!"
        ;;
esac
done

