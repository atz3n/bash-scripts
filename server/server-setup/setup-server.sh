#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

DOMAIN="<server domain>"
USER_NAME="<new sudo user name>"
USER_PWD="<new sudo user password>"

INSTALL_DOCKER=true


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