#!/bin/sh

##################################################################
# CONFIGURATION
##################################################################

USER_NAME="<name of new sudo user>"
USER_PASSWORD="<password of new sudo user>"


##################################################################
# CONFIGURATION
##################################################################



# add user
adduser ${USER_NAME} --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password


# set user password
echo ${USER_NAME}":"${USER_PASSWORD} | chpasswd


# add user to sudo group
usermod -aG sudo ${USER_NAME}


# create users folder for ssh public keys
mkdir ./../home/${USER_NAME}/.ssh


# copy ssh keys to public keys folder
cp .ssh/authorized_keys ./../home/${USER_NAME}/.ssh/


# set ownership to new user
chown -R ${USER_NAME} ./../home/${USER_NAME}/.ssh/


# execute commands as new user:
# make public keys folder visible, accessible and changeable only by new user
# make keys visible and changeable only by new user
su -c "cd ~ ; chmod 700 .ssh ; chmod 600 .ssh/authorized_keys" "${USER_NAME}"


# remove public key in root account (so that ssh isn't accessable via root@<IP> anymore)
rm .ssh/authorized_keys