#!/bin/bash

#
# This script prepares a server on an ubuntu/debian based system
#

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

INSTALL_LETSENCRYPT=false
LETSENCRYPT_RENEW_EVENT="30 2	1 */1 *" # At 02:30 on day-of-month 1 in every month.

INSTALL_DOCKER=false
INSTALL_NGINX=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?o?g?l?e:" opt; do
    case "$opt" in
    h)
        echo "Parameter: [<value> / (flag)]"
        echo "-o  (install docker)"
        echo "-g  (install nginx)"
        echo "-l  (install let's encrypt)"
        echo "-e  <let's encrypt renew event>"
        exit 0
        ;;
    o)
        INSTALL_DOCKER=true
        ;;
    g)  
        INSTALL_NGINX=true
        ;;
    l)  
        INSTALL_LETSENCRYPT=true
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

DISTRO=$(lsb_release -a | grep "Distributor ID")
DISTRO=$(echo ${DISTRO} | sed 's/^Distributor ID: //')
DISTRO="${DISTRO,,}"

PROFILE_LANGUAGE="
export LANGUAGE=\"en_US.UTF-8\"
export LANG=\"en_US.UTF-8\"
export LC_ALL=\"en_US.UTF-8\"
export LC_CTYPE=\"en_US.UTF-8\"
"

UNATTENDED_UPGRADE_PERIODIC_CONFIG="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"

RENEW_CERTIFICATE_SCRIPT="
#!/bin/bash

echo \"[INFO] \$(date)...\" > renew-certificate.log

echo \"[INFO] renewing certificate...\" >> renew-certificate.log
certbot renew >> renew-certificate.log
echo \"\" >> renew-certificate.log
"

SHOW_CERTIFICATES_SCRIPT="
#!/bin/bash

sudo certbot certificates
"

REMOVE_DOMAIN_SCRIPT="
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

echo \"[INFO] removing Let's Encrypt certificate...\"
sudo service nginx stop
sudo certbot delete --cert-name \${DOMAIN}

echo \"[INFO] removing nginx config...\"
sudo rm -f /etc/nginx/conf.d/\${DOMAIN}.http.conf
sudo rm -f /etc/nginx/conf.d/\${DOMAIN}.stream.conf
sudo service nginx start

echo \"[INFO] done. Domain \${DOMAIN} removed.\"
"

STREAM_CONFIG="
stream {
        include /etc/nginx/conf.d/*.stream.conf;
}
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] setting language variables to solve location problems..."
echo "${PROFILE_LANGUAGE}" >> ~/.profile
source ~/.profile


echo "" && echo "[INFO] updating system..."
sudo apt update
sudo apt install -y unattended-upgrades
sudo unattended-upgrades --debug cat /var/log/unattended-upgrades/unattended-upgrades.log

echo "" && echo "[INFO] enabling unattended-upgrade..."
echo "${UNATTENDED_UPGRADE_PERIODIC_CONFIG}" | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null


if [ ${INSTALL_NGINX} == true ] || [ ${INSTALL_LETSENCRYPT} == true ]; then
    echo "" && echo "[INFO] installing nginx..."
    sudo apt install -y nginx libnginx-mod-stream
    sudo service nginx stop

    echo "" && echo "[INFO] configuring nginx..."
    sudo sed -i -e "s|# server_tokens off;|server_tokens off;|g" /etc/nginx/nginx.conf
    sudo sed -i -e "s|# server_names_hash_bucket_size 64;|server_names_hash_bucket_size 64;|g" /etc/nginx/nginx.conf
    sudo sed -i -e "s|include /etc/nginx/conf.d/\*.conf;|include /etc/nginx/conf.d/\*.http.conf;|g" /etc/nginx/nginx.conf
    echo "${STREAM_CONFIG}" | sudo tee -a /etc/nginx/nginx.conf > /dev/null

    sudo rm /etc/nginx/sites-enabled/default
fi


if [ ${INSTALL_DOCKER} == true ]; then
    echo "" && echo "[INFO] installing docker..."

    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt -y remove $pkg; done

    # Add Docker's official GPG key:
    sudo apt -y install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/${DISTRO}/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt -y update

    # Installing docker engine
    sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi


if [ ${INSTALL_LETSENCRYPT} == true ]; then
    echo "" && echo "[INFO] installing Let's Encrypt certbot..."
    sudo apt install -y software-properties-common
    sudo apt install -y python3-certbot-nginx

    echo "" && echo "[INFO] creating Let's Encrypt files..."
    mkdir /home/${LOCAL_USER}/lets-encrypt
    echo "${RENEW_CERTIFICATE_SCRIPT}" > /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh
    sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh

    echo "${SHOW_CERTIFICATES_SCRIPT}" > /home/${LOCAL_USER}/lets-encrypt/show-certificates.sh
    sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/show-certificates.sh

    echo "${REMOVE_DOMAIN_SCRIPT}" > /home/${LOCAL_USER}/lets-encrypt/remove-domain.sh
    sudo chmod 700 /home/${LOCAL_USER}/lets-encrypt/remove-domain.sh

    echo "" && echo "[INFO] creating renew certificate job..."
    (sudo crontab -l 2>> /dev/null; echo "${LETSENCRYPT_RENEW_EVENT}	/bin/bash /home/${LOCAL_USER}/lets-encrypt/renew-certificate.sh") | sudo crontab -
fi


echo "" && echo "[INFO] cleaning up..."
sudo apt -y autoremove

echo "" && echo "[INFO] server preparation done."