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
SCRIPTS_DIRECTORY=`dirname $0`
source "$SCRIPTS_DIRECTORY"/common.sh

# container version (current date)
export APP_VERSION=$(date +"%y%m%d.%H%M%S")
# container internal HTTP port
export APP_PORT=5000
# webapp prefix 
export AZURE_APP_PREFIX="testmcwa"

env_path=$1
if [[ -z $env_path ]]; then
    env_path="$(dirname "${BASH_SOURCE[0]}")/../configuration/.default.env"
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


function deployAzureInfrastructure(){
    subscription=$1
    region=$2
    prefix=$3
    sku=$4
    datadep=$(date +"%y%M%d-%H%M%S")
    resourcegroup="${prefix}rg"
    webapp="${prefix}webapp"

    cmd="az group create  --subscription $subscription --location $region --name $resourcegroup --output none "
    printProgress "$cmd"
    eval "$cmd"

    checkError
    cmd="az deployment group create \
        --name $datadep \
        --resource-group $resourcegroup \
        --subscription $subscription \
        --template-file $SCRIPTS_DIRECTORY/arm-template.json \
        --output none \
        --parameters \
        webAppName=$webapp sku=$sku"
    printProgress "$cmd"
    eval "$cmd"
    checkError
    
    # get ACR login server dns name
    ACR_LOGIN_SERVER=$(az deployment group show --resource-group $resourcegroup -n $datadep | jq -r '.properties.outputs.acrLoginServer.value')
    # get WebApp Url
    WEB_APP_SERVER=$(az deployment group show --resource-group $resourcegroup -n $datadep | jq -r '.properties.outputs.webAppServer.value')
    # get ACR Name
    ACR_NAME=$(az deployment group show --resource-group $resourcegroup -n $datadep | jq -r '.properties.outputs.acrName.value')
    
    cmd="az acr update -n $ACR_NAME --admin-enabled true --output none"
    printProgress "$cmd"
    eval "$cmd"
    checkError

    # get ACR password
    ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" --query passwords[0].value --output tsv)
    # get ACR login
    ACR_LOGIN=$(az acr credential show -n "$ACR_NAME" --query username --output tsv)
}

function undeployAzureInfrastructure(){
    subscription=$1
    prefix=$2
    resourcegroup="${prefix}rg"

    cmd="az group delete  --subscription $subscription  --name $resourcegroup -y --output none "
    printProgress "$cmd"
    eval "$cmd"
}

function buildWebAppContainer() {
    ContainerRegistryName="$1"
    apiModule="$2"
    imageName="$3"
    imageTag="$4"
    imageLatestTag="$5"
    portHttp="$6"

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
    cmd="az acr build --registry $ContainerRegistryName --image ${imageName}:${imageTag} --image ${imageName}:${imageLatestTag} -f Dockerfile --build-arg APP_VERSION=${imageTag} --build-arg ARG_PORT_HTTP=${portHttp} . --output none"
    printProgress "$cmd"
    eval "$cmd"
    
    popd > /dev/null
}

function deployMultiContainer(){
    prefix="$1"
    ContainerRegistryUrl="$2"
    ContainerRegistryLogin="$3"
    ContainerRegistryPassword="$4"
    
    resourcegroup="${prefix}rg"
    webapp="${prefix}webapp"
    # delete containers
    cmd="az webapp config container delete --name $webapp --resource-group $resourcegroup --output none"
    printProgress "$cmd"
    eval "$cmd"

    printProgress "Create Containers"
    tmp_dir=$(mktemp -d -t mc-XXXXXXXXXX)
    sed "s/{ContainerRegistryUrl}/${ContainerRegistryUrl}\//g"  < $SCRIPTS_DIRECTORY/../src/nginx/docker-compose.template.yml | sed "s/{APP_VERSION}/${APP_VERSION}/g" >  $tmp_dir/docker-compose-app-service.yml
    cmd="az webapp config container set --resource-group  "$resourcegroup" --name "$webapp" \
            --multicontainer-config-type compose --multicontainer-config-file $tmp_dir/docker-compose-app-service.yml --output none"
    printProgress "$cmd"
    eval "$cmd"

    printProgress "Create Config"
    cmd="az webapp config appsettings set -g "$resourcegroup" -n "$webapp" \
    --settings DOCKER_REGISTRY_SERVER_URL="$ContainerRegistryUrl" \
    DOCKER_REGISTRY_SERVER_USERNAME="$ContainerRegistryLogin" \
    DOCKER_REGISTRY_SERVER_PASSWORD="$ContainerRegistryPassword" --output none"
    printProgress "$cmd"
    eval "$cmd"

    printProgress "Restart WebApp"
    cmd="az webapp restart --name $webapp --resource-group $resourcegroup --output none"
    printProgress "$cmd"
    eval "$cmd"

}

# Check Azure connection
printMessage "Check Azure connection for subscription: '$AZURE_SUBSCRIPTION_ID'"
azLogin
checkError

# Deploy infrastructure image
printMessage "Deploy infrastructure subscription: '$AZURE_SUBSCRIPTION_ID' region: '$AZURE_REGION' prefix: '$AZURE_APP_PREFIX' sku: 'B2'"
deployAzureInfrastructure $AZURE_SUBSCRIPTION_ID $AZURE_REGION $AZURE_APP_PREFIX "B2"
printMessage "Azure Container Registry DNS name: ${ACR_LOGIN_SERVER}"
printMessage "Azure Web App Url: ${WEB_APP_SERVER}"
printMessage "Azure Container Registry Login: ${ACR_LOGIN}"
printMessage "Azure Container Registry Password: ${ACR_PASSWORD}"


# Build nginx-api docker image
printMessage "Building nginx-api container"
buildWebAppContainer "${ACR_LOGIN_SERVER}" "./src/nginx" "nginx-api" "${APP_VERSION}" "latest" 
checkError

# Build fastapi-api docker image
printMessage "Building fastapi-rest-api container version:${APP_VERSION} port: ${APP_PORT}"
buildWebAppContainer "${ACR_LOGIN_SERVER}" "./src/fastapi-rest-api" "fastapi-rest-api" "${APP_VERSION}" "latest" ${APP_PORT}
checkError

# Build flask-api docker image
printMessage "Building flask-rest-api container version:${APP_VERSION} port: ${APP_PORT}"
buildWebAppContainer "${ACR_LOGIN_SERVER}" "./src/flask-rest-api" "flask-rest-api" "${APP_VERSION}" "latest" ${APP_PORT}
checkError

printMessage "Deploy containers from Azure Container Registry ${ACR_LOGIN_SERVER}"
deployMultiContainer "$AZURE_APP_PREFIX" "${ACR_LOGIN_SERVER}" "${ACR_LOGIN}" "${ACR_PASSWORD}"


# Test services
# Test flask-rest-api
# get nginx local ip address
# connect to container network if in dev container
flask_rest_api_url="https://${WEB_APP_SERVER}/flask-rest-api/version"
printMessage "Testing flask-rest-api url: $flask_rest_api_url expected version: ${APP_VERSION}"
result=$(checkUrl "${flask_rest_api_url}" "${APP_VERSION}" 420)
if [[ $result != "true" ]]; then
    printError "Error while testing flask-rest-api"
else
    printMessage "Testing flask-rest-api successful"
fi

# Test flask-rest-api
fastapi_rest_api_url="https://${WEB_APP_SERVER}/fastapi-rest-api/version"
printMessage "Testing fastapi-rest-api url: $fastapi_rest_api_url expected version: ${APP_VERSION}"
result=$(checkUrl "${fastapi_rest_api_url}" "${APP_VERSION}" 420)
if [[ $result != "true" ]]; then
    printError "Error while testing fastapi-rest-api"
else
    printMessage "Testing fastapi-rest-api successful"
fi

# Undeploy Azure resource 
printMessage "Undeploying all the Azure resources"
undeployAzureInfrastructure $AZURE_SUBSCRIPTION_ID $AZURE_APP_PREFIX

echo "done."