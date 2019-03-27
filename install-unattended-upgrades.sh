#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

###################################################################################################
# DEFINES
###################################################################################################

UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"1\";
"


###################################################################################################
# MAIN
###################################################################################################
 
echo "" && echo "[INFO] enabling unattended-upgrade ..."
echo "${UNATTENDED_UPGRADE_PERIODIC_CONFIG_FILE_CONTENT}" | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null