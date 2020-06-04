#############################
#SET VARIANT FROM PARAMETER
#############################
while getopts u: option
do
 case "${option}"
 in
 u) CREATE_USER=${OPTARG};;
 esac
done

## USER CHECK
if [ -z $CREATE_USER ]
then
 echo "UserName is Required Option Name is -u"
 exit
fi


###########################
# CREATE PRIVATE KEY
###########################

ssh-keygen -t rsa -b 4096 -f /tmp/${CREATE_USER} -P "Runup@)9070"
sudo mkdir -p /home/${CREATE_USER}/.ssh
sudo chmod 700 /home/${CREATE_USER}/.ssh
sudo mv /tmp/${CREATE_USER}.pub /home/${CREATE_USER}/.ssh/authorized_keys
sudo chmod 600 /home/${CREATE_USER}/.ssh/authorized_keys
sudo chown -R ${CREATE_USER}:${CREATE_USER} /home/${CREATE_USER}/.ssh

# DOWNLOAD CONFIRM
ip=$(sudo hostname -I | sed -e 's/^ *//g' -e 's/ *$//g')
host=$(sudo hostname)

echo "scp -i {Super User Key Location} ${USER}@${ip}:/tmp/${CREATE_USER} ./${host}/${CREATE_USER}"
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
