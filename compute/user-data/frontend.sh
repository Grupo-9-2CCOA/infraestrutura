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

REGISTRY="$(printf '%s' '${frontend_image_uri}' | cut -d/ -f1)"
aws ecr get-login-password --region '${aws_region}' | docker login --username AWS --password-stdin "$REGISTRY"
docker pull '${frontend_image_uri}'
docker rm -f doces-com-amor-frontend 2>/dev/null || true
docker run --detach \
  --name doces-com-amor-frontend \
  --restart unless-stopped \
  --publish '${frontend_port}:80' \
  --env BACKEND_HOST='${backend_private_ip}' \
  --env BACKEND_PORT='${backend_port}' \
  '${frontend_image_uri}'
