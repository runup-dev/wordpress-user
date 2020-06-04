# 워드프레스 호스팅용 계정 세팅
# Author : Runup. Kim Tae Oh

#############################
#SET VARIANT FROM PARAMETER
#############################

while getopts u:d:p: option 
do 
 case "${option}" 
 in 
 u) 
    CREATE_USER=${OPTARG}
 ;; 
 d) 
    DOMAIN=${OPTARG}
 ;; 
 p) 
    PASS=${OPTARG}
 ;;
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

## PASS CHECK 
if [ -z $PASS ]
then
 echo "Domain is Required Option Name is -p"
 exit
fi

## 템플릿에 맞게 조정
source account.tmpl

## OS_USER
OS_USER=${OS_USER//\[\[USER\]\]/${CREATE_USER}}
OS_USER=${OS_USER//\[\[PASS\]\]/${PASS}}

## DB_NAME
DB_NAME=${DB_NAME//\[\[USER\]\]/${CREATE_USER}}
DB_NAME=${DB_NAME//\[\[PASS\]\]/${PASS}}

## DB_USER
DB_USER=${DB_USER//\[\[USER\]\]/${CREATE_USER}}
DB_USER=${DB_USER//\[\[PASS\]\]/${PASS}}

## DB_PASS
DB_PASS=${DB_PASS//\[\[USER\]\]/${CREATE_USER}}
DB_PASS=${DB_PASS//\[\[PASS\]\]/${PASS}}

## PRIVATEKEY_PASS
PRIVATEKEY_PASS=${DB_PASS//\[\[USER\]\]/${CREATE_USER}}
PRIVATEKEY_PASS=${DB_PASS//\[\[PASS\]\]/${PASS}}


## 정보기록 
rm -f ./info.txt
touch info.txt
echo "OS USER : ${OS_USER}" >> info.txt
echo "DB NAME : ${DB_NAME}" >> info.txt
echo "DB USER : ${DB_USER}" >> info.txt
echo "DB PASS : ${DB_PASS}" >> info.txt
echo "PRIVATE_KEY_PASS : ${PRIVATEKEY_PASS}" >> info.txt

## DOMAIN VALIDATION
if [ ${DOMAIN:0:4} == "http" -o ${DOMAIN:0:5} == "https" ]
then
  echo "Please Remove http or https Protocol"
  exit
fi



## USER EXISTS CHECK
USER_EXISTS=false
if [ $(getent passwd $OS_USER) ] ; then
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
if [ ! ${USER_EXISTS} == "true" ] ; then
  sudo useradd $OS_USER
else

echo "이미 유저가 존재합니다 계속하시겠어요 ?"
while :
do
read -rp "Y or N) " cf
case $cf in
        [yY])
                break
        ;;

        [nN])
		echo "취소하셨습니다"
                exit
        ;;

        *)
                echo "Please Input Yes or No !!!"
        ;;
esac
done

fi


## MAKE DIRECTORY & PERMITION
sudo mkdir -p /home/${OS_USER}/www
sudo mkdir -p /home/${OS_USER}/www/wordpress
sudo chmod 755 /home/${OS_USER}
sudo chmod 755 /home/${OS_USER}/www
sudo chmod 755 /home/${OS_USER}/www/wordpress
sudo cp ./index.php.tmpl /home/${OS_USER}/www/wordpress/index.php
sudo chown -R ${OS_USER}:${OS_USER} /home/${OS_USER}
sudo chmod 644 /home/${OS_USER}/www/wordpress/index.php


## TODO 
## 호스팅 용량 제한
## 트래픽 용량 제한

## OPCACHE DISABLED WP-CONFIG
blacklist=/etc/php.d/opcache-default.blacklist
blacklist_tmp=opcache-default.blacklist
buffer="/home/${OS_USER}/www/wordpress/wp-config.php"
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
buffer=${buffer//\[\[DB_NAME\]\]/${DB_NAME}}
buffer=${buffer//\[\[USER\]\]/${DB_USER}}
buffer=${buffer//\[\[PASSWD\]\]/${DB_PASS}}
echo "$buffer" > "database.sql"
mysql -u root -p < database.sql
rm -f ./database.sql



###########################
# CREATE PHP-FPM
###########################
pool=/etc/php-fpm.d/${OS_USER}.conf
pool_tmp=${OS_USER}_pool.conf
rm -f ${pool_tmp}
buffer=`cat php-fpm-pool.conf.tmpl`
buffer=${buffer//\[\[USER\]\]/${OS_USER}}

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
vhost_tmp=${OS_USER}_vhost.conf
rm -f ${vhost_tmp}

## ROOT DOMAIN CONFIG
if [ ${DOMAIN:0:3} == "www" ]
then
    buffer=`cat nginx-root-domain.conf.tmpl`
    buffer=${buffer//\[\[USER\]\]/${OS_USER}}
    buffer=${buffer//\[\[DOMAIN\]\]/${DOMAIN}}

    ## ADD SSL
    if [ ${SSL_EXISTS} == "true" ] ; then
	echo "ADD SSL"
    fi
fi

## WWW DOMAIN CONFIG 
buffer=`cat nginx-service-domain.conf.tmpl`
buffer=${buffer//\[\[USER\]\]/${OS_USER}}
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
ip=$(sudo hostname -I | sed -e 's/^ *//g' -e 's/ *$//g')
host=$(sudo hostname)

ssh-keygen -t rsa -b 4096 -f /tmp/ssh-key-${OS_USER} -P ${PRIVATEKEY_PASS}
sudo mkdir -p /home/${OS_USER}/.ssh
sudo chmod 700 /home/${OS_USER}/.ssh
sudo mv /tmp/ssh-key-${OS_USER}.pub /home/${OS_USER}/.ssh/authorized_keys
sudo chmod 600 /home/${OS_USER}/.ssh/authorized_keys
sudo chown -R ${OS_USER}:${OS_USER} /home/${OS_USER}/.ssh

# DOWNLOAD CONFIRM
ip=$(sudo hostname -I | sed -e 's/^ *//g' -e 's/ *$//g')
echo "scp ${USER}@${ip}:/tmp/ssh-key-${OS_USER} {Your Location}"
echo "위 소스를 참고해서 개인키를 안전한 장소에 보관하세요"

while :
do
read -rp "Y or N) " cf
case $cf in
        [yY])
                rm -f /tmp/ssh-key-${OS_USER}
                echo "Good!! please login ${OS_USER} And Setup"
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

