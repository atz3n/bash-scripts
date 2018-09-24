#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

USER_NAME="<name of new sudo user>"
USER_PASSWORD="<password of new sudo user>"


###################################################################################################
# MAIN
###################################################################################################

echo "[INFO] creating user ${USER_NAME} ..."
adduser ${USER_NAME} --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password


echo "[INFO] setting user password ..."
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd


echo "[INFO] adding user to sudo group ..."
usermod -aG sudo ${USER_NAME}


echo "[INFO] copying public keys ..."
mkdir /home/${USER_NAME}/.ssh
cp /root/.ssh/authorized_keys /home/${USER_NAME}/.ssh/
chown -R ${USER_NAME} /home/${USER_NAME}/.ssh/

# setting permissions
# make public keys folder visible, accessible and changeable only by new user
# make keys visible and changeable only by new user
su -c "cd ~ ; chmod 700 .ssh ; chmod 600 .ssh/authorized_keys" "${USER_NAME}"


echo "[INFO] removing public keys from root account (so that root isn't accessable via ssh anymore) ..."
rm /root/.ssh/authorized_keys


echo "[INFO] ...finished. All things are done. Close connection and login as ${USER_NAME} again ..."