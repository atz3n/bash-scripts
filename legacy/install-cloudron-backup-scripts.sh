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

S3CLIENT_CONFIG_FILE_CONTENT="
[default]
access_key = ${STORAGE_ACCESS_KEY}
access_token = 
add_encoding_exts = 
add_headers = 
bucket_location = EU
ca_certs_file = 
cache_file = 
check_ssl_certificate = True
check_ssl_hostname = True
cloudfront_host = cloudfront.amazonaws.com
default_mime_type = binary/octet-stream
delay_updates = False
delete_after = False
delete_after_fetch = False
delete_removed = False
dry_run = False
enable_multipart = True
encoding = UTF-8
encrypt = False
expiry_date = 
expiry_days = 
expiry_prefix = 
follow_symlinks = False
force = False
get_continue = False
gpg_command = /usr/bin/gpg
gpg_decrypt = %(gpg_command)s -d --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_encrypt = %(gpg_command)s -c --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_passphrase = 
guess_mime_type = True
host_base = ${STORAGE_ENDPOINT}
host_bucket = %(bucket)s.${STORAGE_ENDPOINT}
human_readable_sizes = False
invalidate_default_index_on_cf = False
invalidate_default_index_root_on_cf = True
invalidate_on_cf = False
kms_key = 
limit = -1
limitrate = 0
list_md5 = False
log_target_prefix = 
long_listing = False
max_delete = -1
mime_type = 
multipart_chunk_size_mb = 15
multipart_max_chunks = 10000
preserve_attrs = True
progress_meter = True
proxy_host = 
proxy_port = 0
put_continue = False
recursive = False
recv_chunk = 65536
reduced_redundancy = False
requester_pays = False
restore_days = 1
restore_priority = Standard
secret_key = ${STORAGE_SECRET_KEY}
send_chunk = 65536
server_side_encryption = False
signature_v2 = False
signurl_use_https = False
simpledb_host = sdb.amazonaws.com
skip_existing = False
socket_timeout = 300
stats = False
stop_on_error = False
storage_class = 
urlencoding_mode = normal
use_http_expect = False
use_https = True
use_mime_magic = True
verbosity = WARNING
website_endpoint = http://%(bucket)s.s3-website-%(location)s.amazonaws.com/
website_error = 
website_index = index.html
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
echo "${S3CLIENT_CONFIG_FILE_CONTENT}" > .s3cfg


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
