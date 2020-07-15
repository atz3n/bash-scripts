#!/bin/bash

###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

DOMAIN="dummy"

SUDO_USER_NAME="dummy"
SUDO_USER_PWD="dummy"

DISABLE_PASSWORD_REQUEST=false # for full automation

# use with caution. If you want to revoke your decission later, you manually need to edit /etc/ssh/sshd_config
DISABLE_ROOT_LOGIN=false
DISABLE_PASSWORD_LOGIN=false


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?u:p:d:k:r?l?q?" opt; do
    case "$opt" in
    h|\?)
        echo "Parameter:"
        echo "-h  (help)"
        echo "-u  user"
        echo "-p  password"
        echo "-d  domain"
        echo "-q  (disable password request)"
        echo "-r  (disable root login)"
        echo "-l  (disable password login)"
        exit 0
        ;;
    u)  SUDO_USER_NAME=$OPTARG
        ;;
    p)  SUDO_USER_PWD=$OPTARG
        ;;
    d)  DOMAIN=$OPTARG
        ;;
    q)  DISABLE_PASSWORD_REQUEST=true
        ;;
    r)  DISABLE_ROOT_LOGIN=true
        ;;
    l)  DISABLE_PASSWORD_LOGIN=true
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

LIB_FOLDER_PATH="./lib"
CREATE_SUDO_USER_SCRIPT_NAME="create-sudo-user.sh"

CREATE_SUDO_USER_CMD="chmod 700 ${CREATE_SUDO_USER_SCRIPT_NAME} && ./${CREATE_SUDO_USER_SCRIPT_NAME} -u ${SUDO_USER_NAME} -p ${SUDO_USER_PWD}"
DISABLE_ROOT_LOGIN_CMD='sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config'
DISABLE_PASSWORD_LOGIN_CMD='sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config'


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] getting ssh pubkey ..."
SSH_PUB_KEY=$(cat ~/.ssh/id_rsa.pub)


echo "" && echo "[INFO] resetting server's ssh pubkey ..."
SERVER_IP=$(dig +short ${DOMAIN})

if [ $(uname) == Darwin ]; then
    ssh-keygen -R ${DOMAIN};
    ssh-keygen -R ${SERVER_IP};
else 
    ssh-keygen -f /home/$(whoami)/.ssh/known_hosts -R ${DOMAIN}; 
    ssh-keygen -f /home/$(whoami)/.ssh/known_hosts -R ${SERVER_IP}; 
fi


echo "" && echo "[INFO] copying sudo user script to server ..."
scp ${LIB_FOLDER_PATH}/${CREATE_SUDO_USER_SCRIPT_NAME} root@${DOMAIN}:


echo "" && echo "[INFO] creating new sudo user ..."
SERVER_ACCESS_CMD=""

if [ ${DISABLE_ROOT_LOGIN} == true ]; then 
    SERVER_ACCESS_CMD="${DISABLE_ROOT_LOGIN_CMD} && "; 
fi
if [ ${DISABLE_PASSWORD_LOGIN} == true ]; then 
    SERVER_ACCESS_CMD="${SERVER_ACCESS_CMD}${DISABLE_PASSWORD_LOGIN_CMD} && "; 
fi

SERVER_ACCESS_CMD="${SERVER_ACCESS_CMD}${CREATE_SUDO_USER_CMD}"

ssh -t root@${DOMAIN} "echo ${SSH_PUB_KEY} >> .ssh/authorized_keys && ${SERVER_ACCESS_CMD}"


# disable password for full automation
if [ ${DISABLE_PASSWORD_REQUEST} == true ]; then
    echo "" && echo "[INFO] disabling sudo user password request ..."
    ssh -t ${SUDO_USER_NAME}@${DOMAIN} "echo '${SUDO_USER_NAME} ALL=NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo"
fi