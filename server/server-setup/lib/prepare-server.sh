#!/bin/bash

#
# This script prepares a server on an ubuntu based system
#

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

LETSENCRYPT_RENEW_EVENT="30 2	1 */1 *" # At 02:30 on day-of-month 1 in every month.

INSTALL_DOCKER=false
DOCKER_FINGERPRINT="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?d?e:" opt; do
    case "$opt" in
    h)
        echo "Parameter:"
        echo "-e  lets encrypt renew event"
        exit 0
        ;;
    d)
        INSTALL_DOCKER=true
        ;;
    e)  
        LETSENCRYPT_RENEW_EVENT=$OPTARG
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

LOCAL_USER=$(whoami)


PROFILE_LANGUAGE_VARIABLE="
export LANGUAGE=\"en_US.UTF-8\"
export LANG=\"en_US.UTF-8 \"
export LC_ALL=\"en_US.UTF-8\"
export LC_CTYPE=\"en_US.UTF-8\"
"


UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"


RENEW_CERTIFICATE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] \$(date) ...\" > renew-certificate.log

echo \"[INFO] renewing certificate ...\" >> renew-certificate.log
certbot renew >> renew-certificate.log
echo \"\" >> renew-certificate.log
"


SHOW_CERTIFICATES_SCRIPT_CONTENT="
#!/bin/bash

sudo certbot certificates
"


REMOVE_DOMAIN_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

DOMAIN=\"<domain to be removed>\"


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts \"h?d:\" opt; do
    case \"\$opt\" in
    h)
        echo \"Parameter:\"
        echo \"-d  domain to be removed\"
        exit 0
        ;;
    d)
        DOMAIN=\$OPTARG
        ;;
    esac
done


###################################################################################################
# MAIN
###################################################################################################

echo \"[INFO] removing Let's Encrypt certificate ...\"
sudo service nginx stop
sudo certbot delete --cert-name \${DOMAIN}

echo \"[INFO] removing nginx config ...\"
sudo rm /etc/nginx/conf.d/\${DOMAIN}.conf
sudo service nginx start

echo \"[INFO] done. Domain \${DOMAIN} removed.\"
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] setting language variables to solve location problems ..."
echo "${PROFILE_LANGUAGE_VARIABLE}" >> ~/.profile
source ~/.profile


echo "" && echo "[INFO] updating system ..."
sudo apt update
sudo apt install unattended-upgrades -y
sudo unattended-upgrades --debug cat /var/log/unattended-upgrades/unattended-upgrades.log


echo "" && echo "[INFO] installing nginx ..."
sudo apt install -y nginx
sudo service nginx stop


if [ ${INSTALL_DOCKER} == true ]; then

    echo "" && echo "[INFO] installing docker ..."
    sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    if [[ ! $(sudo apt-key fingerprint ${DOCKER_FINGERPRINT}) ]]; then
        echo "" && echo "[ERROR] Docker fingerprint missmatch!!"
        exit 1
    fi

    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io


    echo "" && echo "[INFO] installing docker-composes ..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

fi


echo "" && echo "[INFO] enabling unattended-upgrade ..."
echo "${UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT}" | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null


echo "" && echo "[INFO] configuring nginx ..."
sudo sed -i -e "s/# server_tokens off;/server_tokens off;/g" /etc/nginx/nginx.conf
sudo sed -i -e "s/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g" /etc/nginx/nginx.conf

sudo rm /etc/nginx/sites-enabled/default


echo "" && echo "[INFO] installing Let's Encrypt certbot ..."
sudo apt install -y software-properties-common
sudo apt install -y python3-certbot-nginx


echo "" && echo "[INFO] creating Let's Encrypt files ..."
mkdir /home/${LOCAL_USER}/lets-encrypt
echo "${RENEW_CERTIFICATE_SCRIPT_CONTENT}" > /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh
sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh

echo "${SHOW_CERTIFICATES_SCRIPT_CONTENT}" > /home/${LOCAL_USER}/lets-encrypt/show-certificates.sh
sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/show-certificates.sh

echo "${REMOVE_DOMAIN_SCRIPT_CONTENT}" > /home/${LOCAL_USER}/lets-encrypt/remove-domain.sh
sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/remove-domain.sh


echo "" && echo "[INFO] creating renew certificate job ..."
(sudo crontab -l 2>> /dev/null; echo "${LETSENCRYPT_RENEW_EVENT}	/bin/bash /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh") | sudo crontab -


echo "" && echo "[INFO] cleaning up ..."
sudo apt -y autoremove


echo "" && echo "[INFO] server preparation done."