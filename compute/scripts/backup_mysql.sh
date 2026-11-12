#!/bin/bash
set -uo pipefail

CONFIG_FILE="/etc/mysql-backup.env"
LOG_FILE="/var/log/mysql-backup.log"
umask 077

log() {
  printf '%s [mysql-backup] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "$LOG_FILE"
}

notify() {
  local subject="$1"
  local message="$2"

  if [ -z "${SNS_TOPIC_ARN:-}" ]; then
    log "SNS_TOPIC_ARN is not configured; skipping notification."
    return 0
  fi

  if ! aws sns publish \
    --region "$AWS_REGION" \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "$subject" \
    --message "$message" >/dev/null 2>>"$LOG_FILE"; then
    log "WARNING: failed to publish SNS notification."
  fi
}

fail() {
  local line="$1"
  local code="$2"

  log "ERROR: MySQL backup failed (line $line, exit code $code)."

  notify "Falha no backup MySQL $(date -u '+%Y-%m-%d')" \
"O backup do banco de dados MySQL falhou.

Data: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Banco: ${DB_NAME:-desconhecido}
Host: ${DB_HOST:-desconhecido}
Detalhes: consulte $LOG_FILE na instancia de backup."

  exit "$code"
}

cleanup() {
  if [ -n "${WORK_DIR:-}" ]; then
    rm -rf "$WORK_DIR"
  fi
}

trap 'fail "$LINENO" "$?"' ERR
trap cleanup EXIT

if [ ! -r "$CONFIG_FILE" ]; then
  log "ERROR: configuration file $CONFIG_FILE not found."
  exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

DB_PASSWORD="$(printf '%s' "$DB_PASSWORD_B64" | base64 --decode)"
BACKUP_DATE="$(date -u '+%Y-%m-%d')"
BACKUP_FILE="mysql-backup-$BACKUP_DATE.sql"
WORK_DIR="$(mktemp -d /tmp/mysql-backup.XXXXXX)"
BACKUP_PATH="$WORK_DIR/$BACKUP_FILE"
S3_KEY="$S3_PREFIX/$BACKUP_DATE/$BACKUP_FILE"
START_EPOCH="$(date +%s)"

log "Starting backup of database $DB_NAME on $DB_HOST:$DB_PORT."

MYSQL_PWD="$DB_PASSWORD" mysqldump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --user="$DB_USER" \
  --single-transaction \
  --quick \
  --triggers \
  --no-tablespaces \
  --set-gtid-purged=OFF \
  --default-character-set=utf8mb4 \
  --databases "$DB_NAME" > "$BACKUP_PATH" 2>>"$LOG_FILE"

if [ ! -s "$BACKUP_PATH" ]; then
  log "ERROR: dump file $BACKUP_PATH is empty."
  false
fi

unset DB_PASSWORD

SIZE_BYTES="$(stat -c '%s' "$BACKUP_PATH")"
SIZE_HUMAN="$(numfmt --to=iec-i --suffix=B "$SIZE_BYTES" 2>/dev/null || printf '%s bytes' "$SIZE_BYTES")"

aws s3 cp "$BACKUP_PATH" "s3://$S3_BUCKET/$S3_KEY" \
  --region "$AWS_REGION" \
  --only-show-errors >> "$LOG_FILE" 2>&1

DURATION="$(( $(date +%s) - START_EPOCH ))"

log "Backup uploaded to s3://$S3_BUCKET/$S3_KEY ($SIZE_HUMAN) in ${DURATION}s."

notify "Backup MySQL concluido - $BACKUP_DATE" \
"O backup do banco de dados MySQL foi concluido com sucesso.

Data: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
Banco: $DB_NAME
Host: $DB_HOST:$DB_PORT
Arquivo: $BACKUP_FILE
Destino: s3://$S3_BUCKET/$S3_KEY
Tamanho: $SIZE_HUMAN
Duracao: ${DURATION}s"

log "Backup completed successfully."
exit 0
