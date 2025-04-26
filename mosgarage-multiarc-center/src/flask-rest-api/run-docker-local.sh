#!/bin/bash
set -e
export PORT_HTTP=5000
export APP_VERSION=$(date +"%y%M%d.%H%M%S")
export IMAGE_NAME="flask-rest-api"
export IMAGE_TAG=${APP_VERSION}
export ALTERNATIVE_TAG="latest"

echo "PORT_HTTP $PORT_HTTP"
echo "APP_VERSION $APP_VERSION"
echo "IMAGE_NAME $IMAGE_NAME"
echo "IMAGE_TAG $IMAGE_TAG"
echo "ALTERNATIVE_TAG $ALTERNATIVE_TAG"

result=$(docker image inspect $IMAGE_NAME:$ALTERNATIVE_TAG  2>/dev/null) || true
if [[ ${result} == "[]" ]]; then
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile --build-arg APP_VERSION=${IMAGE_TAG} --build-arg ARG_PORT_HTTP=${PORT_HTTP} .
    #docker push ${IMAGE_NAME}:${IMAGE_TAG}
    # Push with alternative tag
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${ALTERNATIVE_TAG}
    #docker push ${IMAGE_NAME}:${ALTERNATIVE_TAG}
fi
docker run -d -e ARG_PORT_HTTP=${PORT_HTTP}  -e APP_VERSION=${IMAGE_TAG} -p ${PORT_HTTP}:${PORT_HTTP}/tcp    ${IMAGE_NAME}:${ALTERNATIVE_TAG}  
