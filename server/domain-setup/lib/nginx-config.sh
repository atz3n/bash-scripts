#!/bin/bash

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

DOMAIN="<new domain>"
PORT="<new internal port mapping>"


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?p:d:" opt; do
    case "$opt" in
    h)
        echo "Parameter:"
        echo "-d  <new domain>"
        echo "-p  <new internal port mapping>"
        exit 0
        ;;
    d)  
        DOMAIN=$OPTARG
        ;;
    p)  
        PORT=$OPTARG
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

NGINX_LETS_ENCRYPT_GATEWAY_CONFIGURATION_FILE_CONTENT="
server {
    server_name ${DOMAIN};
    listen 80;

    location / {
        proxy_bind 127.0.0.1;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:${PORT}/;
    }
}
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] creating gateway ..."
sudo service nginx stop
echo "${NGINX_LETS_ENCRYPT_GATEWAY_CONFIGURATION_FILE_CONTENT}" | sudo tee /etc/nginx/conf.d/${DOMAIN}.conf > /dev/null


echo "" && echo "[INFO] requesting Let's Encrypt certificate(s) ..."
sudo service nginx start
sudo certbot --nginx --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --redirect -d ${DOMAIN}


echo "" && echo "[INFO] nginx configuration done."
