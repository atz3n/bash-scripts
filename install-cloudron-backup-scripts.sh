#!/bin/bash


###################################################################################################
# DEFAULT CONFIGURATION
###################################################################################################

## REMOTE ##
STORAGE_ACCESS_KEY=""
STORAGE_SECRET_KEY=""
STORAGE_ENDPOINT="ams3.digitaloceanspaces.com"
STORAGE_NAME="some-backups"

CLOUDRON_BACKUP_PATH="/cloudron/" # don't forget the "/" at the end


## LOCAL ##
STORE_PATH="~/cloudron/"
NUMBER_OF_STORED_BACKUPS=7

BACKUP_SCRIPT_PREFIX="cloudron"

ENABLE_CRONJOB=false
BACKUP_PULL_EVENT="0 3 * */2 *" # every 2nd day at 06:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)

###################################################################################################
# PARAMETER PARSING
###################################################################################################

while getopts "h?b:ce:i:p:r:s:n:x:y:" opt; do
    case "$opt" in
    h|\?)
        echo "Description:"
        echo "This script installs backup pull and push scripts to automatically pull "
        echo "cloudron snapshots from an s3 object storage."
        echo "You can use the script with or without parameters in any combination."
        echo "If no parameter is specified, the default value set in the script is used."
        echo ""
        echo "Usage:"
        echo "As explained above, you don't have to use all or at least one parameter "
        echo "if you do your configuration with the default parameter inside the script."
        echo "This is just an example of using all parameter to show how to use them."
        echo ""
        echo "$(basename "$0") -e <storage endpoint> -sn <storage name> -cp <cloudron backup path> -ak <access key> -ak <access secret> -s <store path> -p <backup prefix> -n <number of backups> -c -b <backup time>"
        echo ""
        echo "Parameter:"
        echo "-b  backup pull event time (crontime format)"
        echo "-c  enable cronjob"
        echo "-e  storage endpoint"
        echo "-i  number of stored backups"
        echo "-p  backup script prefix"
        echo "-r  cloudron backup path on object storage"
        echo "-s  local store path"
        echo "-n  storage name"
        echo "-x  storage access key"
        echo "-y  storage secret key"
        exit 0
        ;;
    b)  BACKUP_PULL_EVENT=$OPTARG
        ;;
    c)  ENABLE_CRONJOB=true
        ;;
    e)  STORAGE_ENDPOINT=$OPTARG
        ;;
    i)  NUMBER_OF_STORED_BACKUPS=$OPTARG
        ;;
    p)  BACKUP_SCRIPT_PREFIX=$OPTARG
        ;;
    r) CLOUDRON_BACKUP_PATH=$OPTARG
        ;;
    s)  STORE_PATH=$OPTARG
        ;;
    n) STORAGE_NAME=$OPTARG
        ;;
    x) STORAGE_ACCESS_KEY=$OPTARG
        ;;
    y) STORAGE_SECRET_KEY=$OPTARG
        ;;
    esac
done


###################################################################################################
# DEFINES
###################################################################################################

S3CLIENT_CONFIG_CONTENT="${STORAGE_ACCESS_KEY}
${STORAGE_SECRET_KEY}

${STORAGE_ENDPOINT}
%(bucket)s.${STORAGE_ENDPOINT}


Yes

Y
y
"


PULL_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

STORAGE_NAME=${STORAGE_NAME}
CLOUDRON_BACKUP_PATH=${CLOUDRON_BACKUP_PATH}

STORE_PATH=${STORE_PATH}
NUMBER_OF_STORED_BACKUPS=${NUMBER_OF_STORED_BACKUPS}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/zzz-tmp.txt\"
STORAGE_DOMAIN=\"s3://\${STORAGE_NAME}\${CLOUDRON_BACKUP_PATH}\"


###################################################################################################
# MAIN
###################################################################################################

mkdir -p \${STORE_PATH}


# get backups list
s3cmd ls -l \${STORAGE_DOMAIN} > temp-backup-list.txt

if [ -s /temp.txt ]; then
  echo \"[ERROR] backups not found\"
  rm temp-backup-list.txt
  rm \${TMP_FILE}
  exit
fi


# get backup name and url
sed -i '/snapshot/d' temp-backup-list.txt
tail -n 1 temp-backup-list.txt | xargs > temp-backup.txt

BACKUP_URL=\$(cut -d \" \" -f2 temp-backup.txt)
BACKUP_NAME=\$(basename \${BACKUP_URL})

rm temp-backup-list.txt temp-backup.txt

if [ -d \"\${STORE_PATH}/\${BACKUP_NAME}\" ]; then
  echo \"[INFO] backup folder \${BACKUP_NAME} already exists. Pulling abort\"
  exit
fi


# reduce backups to configured number of backups - 1
ls -1 \${STORE_PATH} > \${TMP_FILE}
NUMBER_OF_FOLDERS=\`wc -l < \${TMP_FILE}\`

while [ \${NUMBER_OF_FOLDERS} -gt \${NUMBER_OF_STORED_BACKUPS} ]
do

  LAST_FOLDER_NAME=\$(head -n 1 \${TMP_FILE})
  rm -rf \"\${STORE_PATH}/\${LAST_FOLDER_NAME}\"

  ls -1 \${STORE_PATH} > \${TMP_FILE}
  NUMBER_OF_FOLDERS=\`wc -l < \${TMP_FILE}\`

done

rm \${TMP_FILE}


# pull backup
mkdir -p \${STORE_PATH}/\${BACKUP_NAME}
s3cmd get -r \${BACKUP_URL} \${STORE_PATH}/\${BACKUP_NAME}

echo \"[INFO] done\"
"


PUSH_BACKUP_SCRIPT_CONTENT="
#!/bin/bash


###################################################################################################
# CONFIGURATION
###################################################################################################

STORAGE_NAME=${STORAGE_NAME}
CLOUDRON_BACKUP_PATH=${CLOUDRON_BACKUP_PATH}

STORE_PATH=${STORE_PATH}


###################################################################################################
# DEFINES
###################################################################################################

TMP_FILE=\"\${STORE_PATH}/000-tmp.txt\"
STORAGE_DOMAIN=\"s3://\${STORAGE_NAME}\${CLOUDRON_BACKUP_PATH}\"


###################################################################################################
# MAIN
###################################################################################################

if [ \$# -eq 0 ]; then

  # get latest backup
  ls -1 \${STORE_PATH} > \${TMP_FILE}
  BACKUP_FOLDER=\$(tail -n 1 \${TMP_FILE})
  rm \${TMP_FILE}


  # check if backup exists
  if [ -z \"\${BACKUP_FOLDER}\" ]; then
    echo \"[ERROR] no backup file found\"
    exit
  fi

elif [ \$# -eq 1  ]; then

  # check if folder exists
  if [ ! -d \"\$1\" ]; then
    echo \"[ERROR] backup name does not match backup name style\"
    exit
  fi


  BACKUP_FOLDER=\$1

else

  echo \"[ERROR] to many arguments\"
  exit

fi


# push backup
s3cmd put -r \${STORE_PATH}/\${BACKUP_FOLDER} \${STORAGE_DOMAIN}
echo \"[INFO] done\"
"


###################################################################################################
# MAIN
###################################################################################################

# adding "-" to existing prefix 
if  ! [ -z "${BACKUP_SCRIPT_PREFIX}" ]; then
    BACKUP_SCRIPT_PREFIX="${BACKUP_SCRIPT_PREFIX}-"
fi


echo "[INFO] Installing s3 client ..."
sudo apt install -y s3cmd

echo "[INFO] Configuring s3 client ..."
echo "${S3CLIENT_CONFIG_CONTENT}" > s3-config.txt
s3cmd --configure < s3-config.txt
rm s3-config.txt


echo "[INFO] creating backup pulling file ..."
echo "$PULL_BACKUP_SCRIPT_CONTENT" > "${BACKUP_SCRIPT_PREFIX}pull-backup.sh"
chmod 700 ${BACKUP_SCRIPT_PREFIX}pull-backup.sh


echo "[INFO] creating backup pushing file ..."
echo "$PUSH_BACKUP_SCRIPT_CONTENT" > "${BACKUP_SCRIPT_PREFIX}push-backup.sh"
chmod 700 ${BACKUP_SCRIPT_PREFIX}push-backup.sh


if [ ${ENABLE_CRONJOB} == true ]; then
  echo "[INFO] creating backup pulling job ..."
  (crontab -l 2>>/dev/null; echo "${BACKUP_PULL_EVENT}	/bin/bash ${PWD}/${BACKUP_SCRIPT_PREFIX}pull-backup.sh") | crontab -
fi
