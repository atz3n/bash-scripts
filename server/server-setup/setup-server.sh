#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

DOMAIN="<server domain>"
USER="<new sudo user name>"
PASSWORD="<new sudo user password>"

# Optional add your ssh public key to the know keys of the new sudo user.
# The known public keys of the root account will be copied to the new sudo user automatically.
# CAUTION: You cannot login to your server if no ssh pub key is known to the new sudo user!!!
# SSH_PUB_KEY_NAME="id_rsa.pub"

INSTALL_DOCKER=false
INSTALL_NGINX=false
INSTALL_LETSENCRYPT=false
SKIP_SUDO_USER=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Parameter: [<value> / (flag)]"
            echo "-d or --domain  <server domain>"
            echo "-p or --password  <new sudo user password>"
            echo "-u or --user  <new sudo user name>"
            echo "-o or --install-docker  (install docker)"
            echo "-g or --install-nginx  (install nginx)"
            echo "-l or --install-letsencrypt  (install let's encrypt)"
            echo "-s or --skip-sudo-user  (skips the creation of new sudo user)"
            exit 0
            ;;
        -o|--install-docker)
            INSTALL_DOCKER=true
            ;;
        -g|--install-nginx)
            INSTALL_NGINX=true
            ;;
        -l|--install-letsencrypt)
            INSTALL_LETSENCRYPT=true
            ;;
        -d|--domain)
            DOMAIN=$2
            shift 
            ;;
        -p|--password)
            PASSWORD=$2
            shift 
            ;;
        -u|--user)
            USER=$2
            shift 
            ;;
        -s|--skip-sudo-user)
            SKIP_SUDO_USER=true
            shift 
            ;;
        *)
            echo "Unknown parameter passed: $1"
            echo "Run with -h or --help for more info"
            exit 1
            ;;
    esac
    shift
done


###################################################################################################
# DEFINES
###################################################################################################

HERE="$(pwd)/$(dirname $0)"


###################################################################################################
# MAIN
###################################################################################################

cd ${HERE}

if [ ${SKIP_SUDO_USER} == false ]; then
    SSH_PUB_KEY_COMMAND=""
    if [ "${SSH_PUB_KEY_NAME}" != "" ]; then
        SSH_PUB_KEY_COMMAND="-k ${SSH_PUB_KEY_NAME}"
    fi
    ./lib/prepare-sudo-user.sh -u ${USER} -p ${PASSWORD} -d ${DOMAIN} ${SSH_PUB_KEY_COMMAND} -r -q -l
fi

PREPARE_SERVER_FLAGS=""
if [ ${INSTALL_DOCKER} == true ]; then PREPARE_SERVER_FLAGS="-o"; fi
if [ ${INSTALL_NGINX} == true ]; then PREPARE_SERVER_FLAGS="${PREPARE_SERVER_FLAGS} -g"; fi
if [ ${INSTALL_LETSENCRYPT} == true ]; then PREPARE_SERVER_FLAGS="${PREPARE_SERVER_FLAGS} -l"; fi

scp ./lib/prepare-server.sh ${USER}@${DOMAIN}:
ssh -t ${USER}@${DOMAIN} "./prepare-server.sh ${PREPARE_SERVER_FLAGS}"
ssh -t ${USER}@${DOMAIN} "rm prepare-server.sh"

echo "" && echo "[INFO] Done. Server set up. Rebooting now..."
ssh -t ${USER}@${DOMAIN} "sudo reboot"
