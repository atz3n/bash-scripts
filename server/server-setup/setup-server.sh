#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

DOMAIN="<server domain>"
USER_NAME="<new sudo user name>"
USER_PWD="<new sudo user password>"

# Optional add your ssh public key to the know keys of the new sudo user.
# The known public keys of the root account will be copied to the new sudo user automatically.
# CAUTION: You cannot login to your server if no ssh pub key is known to the new sudo user!!!
# SSH_PUB_KEY_NAME="id_rsa.pub"

INSTALL_DOCKER=false
INSTALL_NGINX=false
INSTALL_LETSENCRYPT=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?o?g?l?p:d:u:" opt; do
    case "$opt" in
    h)
        echo "Parameter: [<value> / (flag)]"
        echo "-d  <server domain>"
        echo "-p  <new sudo user password>"
        echo "-u  <new sudo user name>"
        echo "-o  (install docker)"
        echo "-g  (install nginx)"
        echo "-l  (install let's encrypt)"
        exit 0
        ;;
    d)  
        DOMAIN=$OPTARG
        ;;
    p)  
        USER_PWD=$OPTARG
        ;;
    u)  
        USER_NAME=$OPTARG
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
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

###################################################################################################
# MAIN
###################################################################################################

SSH_PUB_KEY_COMMAND=""
if [ "${SSH_PUB_KEY_NAME}" != "" ]; then
    SSH_PUB_KEY_COMMAND="-k ${SSH_PUB_KEY_NAME}"
fi

./lib/prepare-sudo-user.sh -u ${USER_NAME} -p ${USER_PWD} -d ${DOMAIN} ${SSH_PUB_KEY_COMMAND} -r -q -l

PS_FLAGS=""
if [ ${INSTALL_DOCKER} == true ]; then PS_FLAGS="-o"; fi
if [ ${INSTALL_NGINX} == true ]; then PS_FLAGS="${PS_FLAGS} -g"; fi
if [ ${INSTALL_LETSENCRYPT} == true ]; then PS_FLAGS="${PS_FLAGS} -l"; fi

scp ./lib/prepare-server.sh ${USER_NAME}@${DOMAIN}:
ssh -t ${USER_NAME}@${DOMAIN} "./prepare-server.sh ${PS_FLAGS}"
ssh -t ${USER_NAME}@${DOMAIN} "rm prepare-server.sh"

echo "" && echo "[INFO] Done. Server set up. Rebooting now..."
ssh -t ${USER_NAME}@${DOMAIN} "sudo reboot"
