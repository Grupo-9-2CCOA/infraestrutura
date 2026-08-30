#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mysql-server

MYSQL_PASSWORD="$(printf '%s' '${mysql_password_b64}' | base64 --decode)"
MYSQL_PASSWORD_SQL="$(printf '%s' "$MYSQL_PASSWORD" | sed "s/'/''/g")"

mysql --protocol=socket <<SQL
CREATE DATABASE IF NOT EXISTS \`${mysql_database}\`;
CREATE USER IF NOT EXISTS '${mysql_user}'@'10.%' IDENTIFIED BY '$MYSQL_PASSWORD_SQL';
ALTER USER '${mysql_user}'@'10.%' IDENTIFIED BY '$MYSQL_PASSWORD_SQL';
GRANT ALL PRIVILEGES ON \`${mysql_database}\`.* TO '${mysql_user}'@'10.%';
FLUSH PRIVILEGES;
SQL

unset MYSQL_PASSWORD MYSQL_PASSWORD_SQL

cat > /etc/mysql/mysql.conf.d/terraform-bind.cnf <<'MYSQL_CONFIG'
[mysqld]
bind-address = 0.0.0.0
mysqlx-bind-address = 127.0.0.1
MYSQL_CONFIG

systemctl enable mysql
systemctl restart mysql
