#!/usr/bin/env bash
# Usage: ./scripts/deploy.sh <service> <image-tag>
# Example: ./scripts/deploy.sh backend abc1234
#
# Called by each repo's GitHub Actions workflow over SSH.
# Pulls the new image for ONE service and restarts only that container.

set -euo pipefail

SERVICE=${1:?Usage: deploy.sh <service> <tag>}
TAG=${2:?Usage: deploy.sh <service> <tag>}

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$INFRA_DIR"

# Load registry URL from .env
ECR_REGISTRY=$(grep ECR_REGISTRY .env | cut -d '=' -f2)

# Update the image tag for this service in .env
case "$SERVICE" in
  backend)        sed -i "s/^BACKEND_TAG=.*/BACKEND_TAG=${TAG}/" .env ;;
  client-frontend) sed -i "s/^CLIENT_TAG=.*/CLIENT_TAG=${TAG}/" .env ;;
  admin-frontend)  sed -i "s/^ADMIN_TAG=.*/ADMIN_TAG=${TAG}/" .env ;;
  *)
    echo "Unknown service: $SERVICE. Must be backend, client-frontend, or admin-frontend."
    exit 1
    ;;
esac

# Authenticate Docker with ECR
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Pull new image and restart only the changed service
docker compose pull "$SERVICE"
docker compose up -d --no-deps "$SERVICE"

echo "Deployed $SERVICE:$TAG successfully."
