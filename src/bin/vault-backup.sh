#!/bin/bash

DEBUG=${DEBUG:-"false"}
BACKUP_DIR=${BACKUP_DIR:-/backups}
BACKUP_ROTATE=${BACKUP_ROTATE:-7}
VAULT_ADDR=${VAULT_ADDR:-""}
VAULT_CACERT=${VAULT_CACERT:-"/tmp/vault_ca.crt"}
VAULT_TOKEN=${VAULT_TOKEN:-""}
AWSCLI_CREDS=${AWSCLI_CREDS:-"$HOME/.aws/credentials"}
S3_ENDPOINT=${S3_ENDPOINT:-"https://s3.amazonaws.com"}
S3_BUCKET_URI=${S3_BUCKET_URI:-""}
GPG_ENABLE_PUB_KEY_IMPORT=${GPG_ENABLE_PUB_KEY_IMPORT:-"false"}
GPG_PUB_KEY=${GPG_PUB_KEY:-""}
GPG_KEYSERVER=${GPG_KEYSERVER:-"https://keys.openpgp.org"}
GPG_KEY_ID=${GPG_KEY_ID:-""}
GPG_RECIPIENT=${GPG_RECIPIENT:-""}
GNUPGHOME=${GNUPGHOME:-"$HOME/.gnupg"}


[[ "${DEBUG}" =~ (1|true) ]] && set -x


function gpg_run() {
  GNUPGHOME=$GNUPGHOME gpg "${@}"
}


function gpg_fetch_pub_key() {
  echo ">>> Fetching GPG key ${GPG_KEY_ID} from ${GPG_KEYSERVER}"
  gpg_run --keyserver "${GPG_KEYSERVER}" --recv-keys "${GPG_KEY_ID}"
}


function gpg_import_pub_key() {
  echo ">>> Importing GPG pub key from environment"
  echo "${GPG_PUB_KEY}" | gpg_run --import
  gpg_run --list-keys
}


function gpg_encrypt() {
  gpg_run \
    --trust-model always \
    --encrypt \
    --recipient "${GPG_RECIPIENT}" \
    --output "${BACKUP_DIR}/vault-backup-${timestamp}.txt.gpg"
  ls -la "${BACKUP_DIR}/vault-backup-${timestamp}.txt.gpg"
}


function backup_vault() {
  echo ">>> Backing up all vault secrets to GPG-encrypted file"
  timestamp=$(date +%Y%m%d%H%M%S)
  safe export -a / | gpg_encrypt
}


function retention() {
  backups_to_delete=$(find "${BACKUP_DIR}" -type f | sort -rn | tail -n +$((${BACKUP_ROTATE} + 1)))
  echo ">>> Running retention (rotate: ${BACKUP_ROTATE})"
  for f in $backups_to_delete; do
    echo "removing ${f}"
    rm -f "${f}"
  done
}


function sync_backups_to_s3() {
  echo ">>> Syncing vault backups to ${S3_BUCKET_URI} (endpoint: ${S3_ENDPOINT})"
  aws --endpoint-url "${S3_ENDPOINT}" s3 sync --delete "${BACKUP_DIR}" "${S3_BUCKET_URI}"
}


function exit_error() {
  echo $1 1>&2
  exit 1
}


function enable_gpg_pub_key_import() {
  [[ "${GPG_ENABLE_PUB_KEY_IMPORT}" =~ (1|true) ]]
}


function validate_input() {
  if [ ! -d "${BACKUP_DIR}" ]; then
    exit_error "BACKUP_DIR does not exist: ${BACKUP_DIR}"
  fi
  if [ "${VAULT_ADDR}" == "" ]; then
    exit_error "Must provide VAULT_ADDR"
  fi
  if [ "${VAULT_TOKEN}" == "" ]; then
    exit_error "Must provide VAULT_TOKEN"
  fi
  if [ ! -f "${VAULT_CACERT}" ]; then
    exit_error "VAULT_CACERT does not exist: ${VAULT_CACER}"
  fi
  if enable_gpg_pub_key_import; then
    if [ "${GPG_PUB_KEY}" == "" ] && [ "${GPG_KEY_ID}" == "" ]; then
      exit_error "Must provide either GPG_PUB_KEY or GPG_KEY_ID (pub key takes precedence)"
    fi
    if [ "${GPG_KEY_ID}" != "" ] && [ "${GPG_KEYSERVER}" == "" ]; then
      exit_error "Must provide GPG_KEYSERVER when GPG_ENABLE_PUB_KEY_IMPORT and GPG_KEY_ID is set"
    fi
  fi
  if [ "${GPG_RECIPIENT}" == "" ]; then
    exit_error "Must provide GPG_RECIPIENT"
  fi
  if [ ! -f "${AWSCLI_CREDS}" ]; then
    exit_error "AWSCLI_CREDS does not exist: ${AWSCLI_CREDS}"
  fi
}


function main() {
  validate_input
  if enable_gpg_pub_key_import; then
    if [ "${GPG_PUB_KEY}" != "" ]; then
      gpg_import_pub_key
    elif [ "${GPG_KEY_ID}" != "" ]; then
      gpg_fetch_pub_key
    fi
  fi
  backup_vault
  retention
  sync_backups_to_s3
}

main
