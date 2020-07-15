#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

USER_NAME="<sudo user name>"

DOMAIN="<application domain>"
APPLICATION_PORT="<application port>"


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?p:d:u:" opt; do
    case "$opt" in
    h)
        echo "Parameter:"
        echo "-d  <new application domain>"
        echo "-p  <new application port>"
        echo "-u  <sudo user name>"
        exit 0
        ;;
    d)  
        DOMAIN=$OPTARG
        ;;
    p)  
        APPLICATION_PORT=$OPTARG
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


scp ./lib/nginx-config.sh ${USER_NAME}@${DOMAIN}:
ssh -t ${USER_NAME}@${DOMAIN} "./nginx-config.sh -d ${DOMAIN} -p ${APPLICATION_PORT}"
ssh -t ${USER_NAME}@${DOMAIN} "rm nginx-config.sh"

echo "" && echo "[INFO] Done. Domain set up."