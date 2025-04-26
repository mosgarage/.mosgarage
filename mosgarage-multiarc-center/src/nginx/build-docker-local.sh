#!/bin/bash
set -e
export PORT_HTTP=5000
export IMAGE_NAME="nginx-api"
export ALTERNATIVE_TAG="latest"

echo "IMAGE_NAME $IMAGE_NAME"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"

docker build -t ${IMAGE_NAME}:${ALTERNATIVE_TAG} -f Dockerfile  .
