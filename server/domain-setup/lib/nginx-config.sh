#!/bin/bash

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

DOMAIN="<new domain>"
PORT="<new internal port mapping>"
ALLOW_WEBSOCKET=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?w?p:d:" opt; do
    case "$opt" in
    h)
        echo "Parameter:"
        echo "-d  <new domain>"
        echo "-p  <new internal port mapping>"
        echo "-w  (allow websocket connection)"
        exit 0
        ;;
    d)  
        DOMAIN=$OPTARG
        ;;
    p)  
        PORT=$OPTARG
        ;;
    w)  
        ALLOW_WEBSOCKET=true
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

NGINX_LETS_ENCRYPT_GATEWAY_CONFIG="
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


NGINX_LETS_ENCRYPT_GATEWAY_WITH_WEBSOCKET_CONFIG="
server {
    server_name ${DOMAIN};
    listen 80;

    location / {
        proxy_bind 127.0.0.1;
        proxy_pass http://127.0.0.1:${PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] creating gateway ..."
sudo service nginx stop

if [ ${ALLOW_WEBSOCKET} == true ]; then
    echo "${NGINX_LETS_ENCRYPT_GATEWAY_WITH_WEBSOCKET_CONFIG}" | sudo tee /etc/nginx/conf.d/${DOMAIN}.conf > /dev/null
else 
    echo "${NGINX_LETS_ENCRYPT_GATEWAY_CONFIG}" | sudo tee /etc/nginx/conf.d/${DOMAIN}.conf > /dev/null
fi


echo "" && echo "[INFO] requesting Let's Encrypt certificate(s) ..."
sudo service nginx start
sudo certbot --nginx --agree-tos --register-unsafely-without-email --rsa-key-size 4096 --redirect -d ${DOMAIN}


echo "" && echo "[INFO] nginx configuration done."
