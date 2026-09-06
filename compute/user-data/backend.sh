#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl docker.io unzip
systemctl enable --now docker

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
GOOGLE_CALENDAR_ID=${google_calendar_id}
ENV
chmod 600 /etc/doces-com-amor/backend.env
unset MYSQL_PASSWORD JWT_SECRET

if [ -n '${google_secret_arn}' ]; then
  aws secretsmanager get-secret-value \
    --region '${aws_region}' \
    --secret-id '${google_secret_arn}' \
    --query SecretString \
    --output text > /etc/doces-com-amor/google-calendar-key.json
  chmod 444 /etc/doces-com-amor/google-calendar-key.json
  echo 'GOOGLE_CALENDAR_CREDENTIALS_PATH=/run/secrets/google-calendar-key.json' >> /etc/doces-com-amor/backend.env
fi

REGISTRY="$(printf '%s' '${backend_image_uri}' | cut -d/ -f1)"
aws ecr get-login-password --region '${aws_region}' | docker login --username AWS --password-stdin "$REGISTRY"
docker pull '${backend_image_uri}'
docker rm -f doces-com-amor-backend 2>/dev/null || true

DOCKER_ARGS=(
  --detach
  --name doces-com-amor-backend
  --restart unless-stopped
  --env-file /etc/doces-com-amor/backend.env
  --publish '${backend_port}:8080'
)

if [ -n '${google_secret_arn}' ]; then
  DOCKER_ARGS+=(--volume /etc/doces-com-amor/google-calendar-key.json:/run/secrets/google-calendar-key.json:ro)
fi

docker run "$${DOCKER_ARGS[@]}" '${backend_image_uri}'
