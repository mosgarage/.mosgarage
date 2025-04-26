#!/bin/bash
#
# executable
#

set -e
# Read variables in configuration file
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../"
    pwd -P
)
source `dirname $0`/common.sh

# container version (current date)
export APP_VERSION=$(date +"%y%M%d.%H%M%S")
# container internal HTTP port
export APP_PORT=5000

env_path=$1
if [[ $env_path ]]; then
    env_path="./configuration/.default.env"
fi

printMessage "Starting test with local Docker service using the configuration in this file ${env_path}"

if [[ $env_path ]]; then
    if [ ! -f "$env_path" ]; then
        printError "$env_path does not exist."
        exit 1
    fi
    set -o allexport
    source "$env_path"
    set +o allexport
else
    printWarning "No env. file specified. Using environment variables."
fi



function buildWebAppContainer() {
    apiModule="$1"
    imageName="$2"
    imageTag="$3"
    imageLatestTag="$4"
    portHttp="$5"

    targetDirectory="$(dirname "${BASH_SOURCE[0]}")/../$apiModule"

    if [ ! -d "$targetDirectory" ]; then
            echo "Directory '$targetDirectory' does not exist."
            exit 1
    fi

    echo "Building and uploading the docker image for '$apiModule'"

    # Navigate to API module folder
    pushd "$targetDirectory" > /dev/null

    # Build the image
    echo "Building the docker image for '$imageName:$imageTag'"
    docker build -t ${imageName}:${imageTag} -f Dockerfile --build-arg APP_VERSION=${imageTag} --build-arg ARG_PORT_HTTP=${portHttp} .
    # Push with alternative tag
    docker tag ${imageName}:${imageTag} ${imageName}:${imageLatestTag}
    
    popd > /dev/null

}

function clearImage(){
    imageName="$1"
    # stop the container
    docker container stop "$1" 2>/dev/null || true
    # remove the container
    docker container rm "$1" 2>/dev/null || true
    # remove the images
    result=$(docker images --filter=reference="${imageName}:*" -q | head -n 1)
    while [ -n "${result}" ]
    do
        docker rmi -f ${result}
        result=$(docker images --filter=reference="${imageName}:*" -q | head -n 1)
    done
}

# Build nginx-api docker image
printMessage "Building nginx-api container"
clearImage "nginx-api"
buildWebAppContainer "./src/nginx" "nginx-api" "${APP_VERSION}" "latest" 
checkError

# Build fastapi-api docker image
printMessage "Building fastapi-rest-api container version:${APP_VERSION} port: ${APP_PORT}"
clearImage "fastapi-rest-api"
buildWebAppContainer "./src/fastapi-rest-api" "fastapi-rest-api" "${APP_VERSION}" "latest" ${APP_PORT}
checkError

# Build flask-api docker image
printMessage "Building flask-rest-api container version:${APP_VERSION} port: ${APP_PORT}"
clearImage "flask-rest-api"
buildWebAppContainer "./src/flask-rest-api" "flask-rest-api" "${APP_VERSION}" "latest" ${APP_PORT}
checkError

# Deploy nginx, fastapi-rest-api, flask-rest-api
printMessage "Deploying all the containers"
targetDirectory="$(dirname "${BASH_SOURCE[0]}")/../src/nginx"
pushd "$targetDirectory" > /dev/null
docker-compose up  -d
checkError
popd > /dev/null

# Test services
# Test flask-rest-api
# get nginx local ip address
# connect to container network if in dev container
ip=$(get_local_host "nginx-api")
flask_rest_api_url="http://$ip/flask-rest-api/version"
printMessage "Testing flask-rest-api url: $flask_rest_api_url expected version: ${APP_VERSION}"
result=$(checkUrl "${flask_rest_api_url}" "${APP_VERSION}" 300)
if [[ $result != "true" ]]; then
    printError "Error while testing flask-rest-api"
else
    printMessage "Testing flask-rest-api successful"
fi

# Test flask-rest-api
fastapi_rest_api_url="http://$ip/fastapi-rest-api/version"
printMessage "Testing fastapi-rest-api url: $fastapi_rest_api_url expected version: ${APP_VERSION}"
result=$(checkUrl "${fastapi_rest_api_url}" "${APP_VERSION}" 300)
if [[ $result != "true" ]]; then
    printError "Error while testing fastapi-rest-api"
else
    printMessage "Testing fastapi-rest-api successful"
fi

# Undeploy nginx, fastapi-rest-api, flask-rest-api
printMessage "Undeploying all the containers"
targetDirectory="$(dirname "${BASH_SOURCE[0]}")/../src/nginx"
pushd "$targetDirectory" > /dev/null
docker-compose down 
checkError
popd

echo "done."