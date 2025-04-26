#!/bin/bash
#
# executable
#
# apply Terraform template to deploy cosmos and app service

set -e
# Read variables in configuration file
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../../../"
    pwd -P
)
export "$(grep targetEnvironmentTfName "$parent_path""/configs/.env")"
export "$(grep azSubscriptionName "$parent_path""/configs/.env")"
export "$(grep rgDevOpsTfState "$parent_path""/configs/.env")"
export "$(grep tfStorageAccountName "$parent_path""/configs/.env")"
export "$(grep tfContainerName "$parent_path""/configs/.env")"
export "$(grep managedIdentityClientId "$parent_path""/configs/.env")"
export "$(grep azureTenant "$parent_path""/configs/.env")"
export "$(grep azureSubscription "$parent_path""/configs/.env")"
export "$(grep companyDatalakeName "$parent_path""/configs/.env")"
export "$(grep companyDatalakeAccessKey "$parent_path""/configs/.env")"
export "$(grep companyDatalakeContainerName "$parent_path""/configs/.env")"
export "$(grep companyWebAppName "$parent_path""/configs/.env")"
export "$(grep companyWebAppRG "$parent_path""/configs/.env")"
export "$(grep commonContainerRegistryPwd "$parent_path""/configs/.env")"
export "$(grep commonContainerRegistryUrl "$parent_path""/configs/.env")"
export "$(grep commonContainerRegistryLogin "$parent_path""/configs/.env")"
export "$(grep commonContainerRegistryName "$parent_path""/configs/.env")"

# Force sandbox env
targetEnvironmentTfName=sandbox
# expected environment variables; one can override them as arguments
targetEnvironmentTfName=${1:-$targetEnvironmentTfName}
azSubscriptionName=${2:-$azSubscriptionName}
rgDevOpsTfState=${3:-$rgDevOpsTfState}
tfStorageAccountName=${4:-$tfStorageAccountName}
tfContainerName=${5:-$tfContainerName}
managedIdentityClientId=${6:-$managedIdentityClientId}

echo "targetEnvironmentTfName=[$targetEnvironmentTfName]"
echo "azSubscriptionName=[$azSubscriptionName]"
echo "rgDevOpsTfState=[$rgDevOpsTfState]"
echo "tfStorageAccountName=[$tfStorageAccountName]"
echo "tfContainerName=[$tfContainerName]"
echo "managedIdentityClientId=[$managedIdentityClientId]"


az account set -s "$azSubscriptionName"

pushd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" > /dev/null
source "./init-vars.sh"
source "./utils.sh"
popd > /dev/null

# Checks whether the process is logged in on Azure
azLogin


function buildWebAppContainer() {
        apiModule="$1"
        imageName="$2"
        imageTag="$3"

        if [ ! -d "$apiModule" ]; then
                echo "Directory '$apiModule' does not exist."
                exit 1
        fi

        echo "Building and uploading the docker image for '$apiModule'"

        # Navigate to API module folder
        pushd "$(dirname "${BASH_SOURCE[0]}")/../../../$apiModule" > /dev/null
        # Generate the wheel file

        make dist

        # Build the image
        echo "Building and uploading the docker image for '$imageName:$imageTag'"
        az acr build --registry "$commonContainerRegistryName" --image "$imageName:$imageTag" .

        popd > /dev/null

}

# Checks wheather the process is logged in on Azure
azLogin

# Build and upload DATASHOP API images on Azure Container Registry & create web app
buildWebAppContainer "./src/nginx" "nginx" "latest" "$companyWebAppName" "$companyWebAppRG"

# Build and upload DATASHOP API images on Azure Container Registry & create web app
buildWebAppContainer "./src/datashop-api" "datashop-api" "latest" "$companyWebAppName" "$companyWebAppRG"

# Build and upload the COMPANY API images on Azure Container Registry & create web app
buildWebAppContainer "./src/company-api" "company-api" "latest" "$companyWebAppName" "$companyWebAppRG"

echo "Delete Containers"
az webapp config container delete --name "$companyWebAppName" --resource-group "$companyWebAppRG"
echo "Create Containers"
sed "s/{ContainerRegistryName}/$commonContainerRegistryName/g" < ./src/nginx/docker-compose.template.yml >  ./src/nginx/docker-compose.yml
az webapp config container set --resource-group  "$companyWebAppRG" --name "$companyWebAppName" \
        --multicontainer-config-type compose --multicontainer-config-file ./src/nginx/docker-compose.yml

echo "Create Config"
az webapp config appsettings set -g "$companyWebAppRG" -n "$companyWebAppName" \
 --settings DOCKER_REGISTRY_SERVER_URL="$commonContainerRegistryUrl" \
  DOCKER_REGISTRY_SERVER_USERNAME="$commonContainerRegistryLogin" \
  DOCKER_REGISTRY_SERVER_PASSWORD="$commonContainerRegistryPwd"

echo "Restart WebApp"
az webapp restart --name "$companyWebAppName" --resource-group "$companyWebAppRG"

# Upload sample data files to the datalake
# Data sample is split into multiple files to "mockup" big data transfer
az storage blob upload-batch --destination "$companyDatalakeContainerName" \
    --account-name "$companyDatalakeName" \
    --account-key "$companyDatalakeAccessKey" \
    --source "$(dirname "${BASH_SOURCE[0]}")/../../../test-data/integ-tests"

# Test datashop/datasets endpoint on DATASHOP API, ensure it sends back a payload with datasets in it
datashopApiUrl="https://$companyWebAppName.azurewebsites.net/datashop/datasets"
waitForUrl "$datashopApiUrl"

response=$(curl -X GET -s "$datashopApiUrl" | jq -r '.items' | jq length)

if [[ $response = 0 ]]; then
     # If payload is invalid, or does not contain any items, quit with error
     echo "Error: The endpoint 'datashop/datasets' did not return the correct json payload."
     exit 1
fi

# Test /datasets/[id]/status endpoint, ensure status==ready (so the blob 'exists')
companyUrl="https://$companyWebAppName.azurewebsites.net/datasets/123/status"
waitForUrl "$companyUrl"

response=$(curl -X GET -s "$companyUrl" | jq -r '.status')

if [[ $response = "null" ]]; then
     echo "Error: The endpoint '/datasets/[id]/status' did not return the correct json payload."
     exit 1
fi

if [[ $response != "ready" ]]; then
    echo "Error: The file is not present in the datalake."
    exit 1
fi

# Ensure now that the blob exists on the DataLake (that the process has completely pushed the bought dataset)
blobName="div_1_features_1.csv"
blobExists=$(az storage blob exists --container-name "$companyDatalakeContainerName" \
    --name "$blobName" \
    --account-name "$companyDatalakeName" \
    --account-key "$companyDatalakeAccessKey" | jq -r '.exists')

if [[ $blobExists != "true" ]]; then
    echo "The blob '$blobName' does not exist in the datalake '$companyDatalakeName'."
    exit 1
fi

echo "done."