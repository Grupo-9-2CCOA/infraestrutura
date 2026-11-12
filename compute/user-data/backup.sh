#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mysql-client curl unzip ca-certificates cron

if ! command -v aws >/dev/null 2>&1; then
  MACHINE_ARCH="$(uname -m)"
  case "$MACHINE_ARCH" in
    x86_64)
      AWS_ARCH="x86_64"
      ;;
    aarch64)
      AWS_ARCH="aarch64"
      ;;
    *)
      echo "Unsupported architecture: $MACHINE_ARCH" >&2
      exit 1
      ;;
  esac

  curl --fail --silent --show-error \
    "https://awscli.amazonaws.com/awscli-exe-linux-$AWS_ARCH.zip" \
    --output /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

install -d -m 0700 /opt/mysql-backup

cat > /etc/mysql-backup.env <<EOF
AWS_REGION='${aws_region}'
S3_BUCKET='${backup_bucket_name}'
S3_PREFIX='mysql-backups'
SNS_TOPIC_ARN='${backup_sns_topic_arn}'
DB_HOST='${mysql_private_ip}'
DB_PORT='3306'
DB_NAME='${mysql_database}'
DB_USER='${mysql_user}'
DB_PASSWORD_B64='${mysql_password_b64}'
EOF
chmod 0600 /etc/mysql-backup.env

printf '%s' '${backup_script_b64}' | base64 --decode > /opt/mysql-backup/backup_mysql.sh
chmod 0700 /opt/mysql-backup/backup_mysql.sh

touch /var/log/mysql-backup.log
chmod 0640 /var/log/mysql-backup.log

cat > /etc/cron.d/mysql-backup <<EOF
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
${backup_schedule} root /opt/mysql-backup/backup_mysql.sh >> /var/log/mysql-backup.log 2>&1
EOF
chmod 0644 /etc/cron.d/mysql-backup

systemctl enable cron >/dev/null 2>&1 || true
systemctl restart cron

# Run once after the database is reachable so the administrator receives a
# first success/failure notification. Failures are reported by SNS and do not
# interrupt the instance bootstrap.
for attempt in $(seq 1 60); do
  if (echo > /dev/tcp/${mysql_private_ip}/3306) >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

/opt/mysql-backup/backup_mysql.sh >> /var/log/mysql-backup.log 2>&1 || true
