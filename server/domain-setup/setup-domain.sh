#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

USER_NAME="<sudo user name>"

DOMAIN="<application domain>"
APPLICATION_PORT="<application port>"

ALLOW_WEBSOCKET=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?w?p:d:u:" opt; do
    case "$opt" in
    h)
        echo "Parameter: [<value> / (flag)]"
        echo "-d  <new application domain>"
        echo "-p  <new application port>"
        echo "-u  <sudo user name>"
        echo "-w  (allow websocket connection)"
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
    w)  
        ALLOW_WEBSOCKET=true
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

HERE="$(pwd)/$(dirname $0)"


###################################################################################################
# MAIN
###################################################################################################

cd ${HERE}

WF=""
if [ ${ALLOW_WEBSOCKET} == true ]; then WF="-w"; fi

scp ./lib/nginx-config.sh ${USER_NAME}@${DOMAIN}:
ssh -t ${USER_NAME}@${DOMAIN} "./nginx-config.sh -d ${DOMAIN} -p ${APPLICATION_PORT} ${WF}"
ssh -t ${USER_NAME}@${DOMAIN} "rm nginx-config.sh"

echo "" && echo "[INFO] Done. Domain set up."