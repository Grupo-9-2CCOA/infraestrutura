#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl docker.io unzip

systemctl enable --now docker

if [ '${install_rabbitmq}' = "true" ]; then
  apt-get install -y rabbitmq-server

  # RabbitMQ must accept connections from the Lambda consumer over the VPC.
  mkdir -p /etc/rabbitmq
  cat > /etc/rabbitmq/rabbitmq.conf <<EOF
listeners.tcp.default = 5672
loopback_users.guest = false
EOF

  systemctl enable rabbitmq-server
  systemctl restart rabbitmq-server
  for attempt in $(seq 1 30); do
    rabbitmqctl await_startup >/dev/null 2>&1 && break
    sleep 2
  done
  rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"
fi

curl --fail --silent --show-error \
  'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' \
  --output /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

MYSQL_PASSWORD="$(printf '%s' '${mysql_password_b64}' | base64 --decode)"
JWT_SECRET="$(printf '%s' '${jwt_secret_b64}' | base64 --decode)"

install -d -m 700 /etc/doces-com-amor
cat > /etc/doces-com-amor/backend.env <<ENV
SPRING_DATASOURCE_URL=jdbc:mysql://${mysql_private_ip}:3306/${mysql_database}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
SPRING_DATASOURCE_USERNAME=${mysql_user}
SPRING_DATASOURCE_PASSWORD=$MYSQL_PASSWORD
JWT_SECRET=$JWT_SECRET
JWT_VALIDITY=3600
SPRING_RABBITMQ_HOST='${rabbitmq_host}'
SPRING_RABBITMQ_PORT=5672
SPRING_RABBITMQ_USERNAME=guest
SPRING_RABBITMQ_PASSWORD=guest
COOKIE_SECURE=false
ENV
chmod 600 /etc/doces-com-amor/backend.env
unset MYSQL_PASSWORD JWT_SECRET

REGISTRY="$(printf '%s' '${backend_image_uri}' | cut -d/ -f1)"
case "$REGISTRY" in
  *.dkr.ecr.*.amazonaws.com)
    aws ecr get-login-password --region '${aws_region}' | docker login --username AWS --password-stdin "$REGISTRY"
    ;;
esac
docker pull '${backend_image_uri}'
docker rm -f doces-com-amor-backend 2>/dev/null || true

docker run \
  --detach \
  --name doces-com-amor-backend \
  --restart unless-stopped \
  --add-host host.docker.internal:host-gateway \
  --env-file /etc/doces-com-amor/backend.env \
  --publish '${backend_port}:8080' \
  '${backend_image_uri}'
