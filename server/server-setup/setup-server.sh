#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

DOMAIN="<server domain>"
USER_NAME="<new sudo user name>"
USER_PWD="<new sudo user password>"

INSTALL_DOCKER=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?i?p:d:u:" opt; do
    case "$opt" in
    h)
        echo "Parameter:"
        echo "-d  <server domain>"
        echo "-i  (install docker)"
        echo "-p  <new sudo user password>"
        echo "-u  <new sudo user name>"
        exit 0
        ;;
    d)  
        DOMAIN=$OPTARG
        ;;
    i)  
        INSTALL_DOCKER=true
        ;;
    p)  
        USER_PWD=$OPTARG
        ;;
    u)  
        USER_NAME=$OPTARG
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

###################################################################################################
# MAIN
###################################################################################################

./lib/prepare-sudo-user.sh -u ${USER_NAME} -p ${USER_PWD} -d ${DOMAIN} -r -q -l

DF=""
if [ ${INSTALL_DOCKER} == true ]; then DF="-d"; fi

scp ./lib/prepare-server.sh ${USER_NAME}@${DOMAIN}:
ssh -t ${USER_NAME}@${DOMAIN} "./prepare-server.sh ${DF}"
ssh -t ${USER_NAME}@${DOMAIN} "rm prepare-server.sh"

echo "" && echo "[INFO] Done. Server set up. Rebooting now ..."
ssh -t ${USER_NAME}@${DOMAIN} "sudo reboot"