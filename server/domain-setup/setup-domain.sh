#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

USER="<sudo user name>"

DOMAIN="<application domain>"
APPLICATION_PORT="<application port>"

ALLOW_WEBSOCKET=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Parameter: [<value> / (flag)]"
            echo "-d or --domain  <new application domain>"
            echo "-p or --port  <new application port>"
            echo "-u or --user  <sudo user name>"
            echo "-w or --allow-websocket  (allow websocket connection)"
            exit 0
            ;;
        -w|--allow-websocket)
            ALLOW_WEBSOCKET=true
            ;;
        -d|--domain)
            DOMAIN+=($2)
            shift 
            ;;
        -p|--port)
            APPLICATION_PORT+=($2)
            shift 
            ;;
        -u|--user)
            USER+=($2)
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

WEBSOCKET_FLAG=""
if [ ${ALLOW_WEBSOCKET} == true ]; then WEBSOCKET_FLAG="-w"; fi

scp ./lib/nginx-config.sh ${USER}@${DOMAIN}:
ssh -t ${USER}@${DOMAIN} "./nginx-config.sh -d ${DOMAIN} -p ${APPLICATION_PORT} ${WEBSOCKET_FLAG}"
ssh -t ${USER}@${DOMAIN} "rm nginx-config.sh"

echo "" && echo "[INFO] Done. Domain set up."