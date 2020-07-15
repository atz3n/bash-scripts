#!/bin/bash


###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

SERVER_DOMAIN="<server domain>"

BACKUP_USER_NAME="<servers backup name>"
BACKUP_FILE_PREFIX=""

STORE_PATH="~"
NUMBER_OF_STORED_BACKUPS=14

ENABLE_CRONJOB=false
BACKUP_PULL_EVENT="0 6	* * *" # every day at 06:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)


###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?d:u:p:s:n:cb:" opt; do
    case "$opt" in
    h|\?)
        echo "Description:"
        echo "This script installs backup pull and push scripts to automatically pull "
        echo "backups from an infrastructure server. To restore a server, you can easily"
        echo "push a backup to the server using the backup push script."
        echo "You can use the script with or without parameters in any combination."
        echo "If no parameter is specified, the default value set in the script is used."
        echo ""
        echo "Usage:"
        echo "As explained above, you don't have to use all or at least one parameter "
        echo "if you do your configuration with the default parameter inside the script."
        echo "This is just an example of using all parameter to show how to use them."
        echo ""
        echo "$(basename "$0") -d <server domain> -u <backup user> -p <backup prefix> -s <storage path> -n <number of backups> -c -b <backup time>"
        echo ""
        echo "Parameter:"
        echo "-b  backup pull event time (crontime format)"
        echo "-c  enable cronjob"
        echo "-d  server domain"
        echo "-p  backup file prefix"
        echo "-s  backup storage path"
        echo "-u  servers backup user"
        echo "-n  number of stored backups"
        exit 0
        ;;
    d)  SERVER_DOMAIN=$OPTARG
        ;;
    u)  BACKUP_USER_NAME=$OPTARG
        ;;
    p)  BACKUP_FILE_PREFIX=$OPTARG
        ;;
    s)  STORE_PATH=$OPTARG
        ;;
    n)  NUMBER_OF_STORED_BACKUPS=$OPTARG
        ;;
    c)  ENABLE_CRONJOB=true
        ;;
    b)  BACKUP_PULL_EVENT=$OPTARG
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

PULL_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

BACKUP_USER_NAME=${BACKUP_USER_NAME}
SERVER_DOMAIN=${SERVER_DOMAIN}

STORE_PATH=${STORE_PATH}
NUMBER_OF_STORED_BACKUPS=${NUMBER_OF_STORED_BACKUPS}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/zzz-tmp.txt\"


###################################################################################################
# MAIN
###################################################################################################

mkdir -p \${STORE_PATH}


# reduce backups to configured number of backups - 1
ls -1 \${STORE_PATH} > \${TMP_FILE}
NUMBER_OF_FILES=\`wc -l < \${TMP_FILE}\`

while [ \${NUMBER_OF_FILES} -gt \${NUMBER_OF_STORED_BACKUPS} ]
do

  LAST_FILE_NAME=\$(head -n 1 \${TMP_FILE})
  rm \"\${STORE_PATH}/\${LAST_FILE_NAME}\"

  ls -1 \${STORE_PATH} > \${TMP_FILE}
  NUMBER_OF_FILES=\`wc -l < \${TMP_FILE}\`

done

rm \${TMP_FILE}


# pull backup
scp \${BACKUP_USER_NAME}@\${SERVER_DOMAIN}:persist/* \${STORE_PATH}
echo \"[INFO] done\"
"


PUSH_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

BACKUP_USER_NAME=${BACKUP_USER_NAME}
SERVER_DOMAIN=${SERVER_DOMAIN}

STORE_PATH=${STORE_PATH}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/aaa-tmp.txt\"


###################################################################################################
# MAIN
###################################################################################################

if [ \$# -eq 0 ]; then
  
  # get latest backup
  ls -1 \${STORE_PATH} > \${TMP_FILE}
  BACKUP_FILE=\$(tail -n 1 \${TMP_FILE})
  rm \${TMP_FILE}
  

  # check if backup exists
  if [[ \${BACKUP_FILE} != ${BACKUP_FILE_PREFIX}-backup-* ]] || [[ \${BACKUP_FILE} != *.tar.gz.enc ]]; then 
    echo \"[ERROR] no backup file found\"
    exit
  fi

elif [ \$# -eq 1  ]; then

  # check if parameter starts with \"${BACKUP_FILE_PREFIX}-backup-\" and ends with \".tar.gz.enc\"
  if [[ \$1 != ${BACKUP_FILE_PREFIX}-backup-* ]] || [[ \$1 != *.tar.gz.enc ]] ; then 
    echo \"[ERROR] backup name does not match backup name style\"
    exit
  fi

  
  BACKUP_FILE=\$1

else

  echo \"[ERROR] to many arguments\"
  exit

fi


# push backup
scp \${STORE_PATH}/\${BACKUP_FILE} \${BACKUP_USER_NAME}@\${SERVER_DOMAIN}:restore/
echo \"[INFO] done\"
"


###################################################################################################
# MAIN
###################################################################################################

# adding "-" to existing prefix 
if  ! [ -z "${BACKUP_FILE_PREFIX}" ]; then
    BACKUP_FILE_PREFIX="${BACKUP_FILE_PREFIX}-"
fi


echo "[INFO] creating backup pulling file ..."
echo "$PULL_BACKUP_SCRIPT_CONTENT" > "${BACKUP_FILE_PREFIX}pull-backup.sh"
chmod 700 ${BACKUP_FILE_PREFIX}pull-backup.sh


echo "[INFO] creating backup pushing file ..."
echo "$PUSH_BACKUP_SCRIPT_CONTENT" > "${BACKUP_FILE_PREFIX}push-backup.sh"
chmod 700 ${BACKUP_FILE_PREFIX}push-backup.sh


if [ ${ENABLE_CRONJOB} == true ]; then
  echo "[INFO] creating backup pulling job ..."
  (crontab -l 2>>/dev/null; echo "${BACKUP_PULL_EVENT}	/bin/bash ${PWD}/${BACKUP_FILE_PREFIX}pull-backup.sh") | crontab -
fi


echo "[INFO] done"