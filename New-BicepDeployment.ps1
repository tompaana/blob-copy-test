# This script provisions resources specified in /bicep/main.bicep to Azure
#
# Usage:
#
# .\New-BicepDeployment.ps1 `
#       -ResourceNameMeronym <resource name meronym> `
#       -Environment <environment {dev, test, prod}, default is "dev"> `
#       -SubscriptionId `  # If not given, the script will attempt to retrieve it
#       -UserObjectId  # If not given, the script will attempt to retrieve it
#       {-UseServiceEndpoints}
#
# Tested to work with Azure CLI version 2.56.0

Param(
    [Parameter(Mandatory, HelpMessage="Resource name meronym (lowercase alphanumeric, max length 2)")][string]$ResourceNameMeronym,
    [string]$Environment = "dev",
    [string]$SubscriptionId = "",
    [string]$UserObjectId = "",
    [switch]$UseServiceEndpoints
)

$ErrorActionPreference = "Stop"

if ($ResourceNameMeronym.Length -ne 2) {
    Write-Error "Invalid argument: Resource name meronym has invalid length - must be exactly 2"
    exit 1
}

if ($Environment -ne "dev" -and $Environment -ne "test" -and $Environment -ne "prod") {
    Write-Error "Invalid argument: Environment given was ""${Environment}"", but the valid values are: ""dev"", ""test"" or ""prod"""
    exit 1
}

if ($SubscriptionId.Length -eq 0) {
    try {
        Write-Output "No subscription ID given, retrieving current subscription information..."
        $AccountInformation = (az account show | ConvertFrom-Json)
    }
    catch {
        Write-Error "Failed to retrieve the information of the account: ${_}"
        exit 1
    }

    $SubscriptionId = $AccountInformation.id

    if ($SubscriptionId.Length -ne 36) {
        Write-Error "Failed to retrieve the subscription ID"
        exit 1
    }
}

if ($UserObjectId.Length -eq 0) {
    try {
        Write-Output "No user object ID given, retrieving signed in user information..."
        $SignedInUserInformation = (az ad signed-in-user show | ConvertFrom-Json)
    }
    catch {
        Write-Error "Failed to retrieve the information of the signed in user: ${_}"
        exit 1
    }

    $UserObjectId = $SignedInUserInformation.id

    if ($UserObjectId.Length -ne 36) {
        Write-Error "Failed to retrieve the object ID of the signed in user"
        exit 1
    }
}

Write-Output "`nDeploying with following config:"
Write-Output "  - Resource name meronym: ${ResourceNameMeronym}"
Write-Output "  - Environment: ${Environment}"
Write-Output "  - Subscription ID: ${SubscriptionId}"
Write-Output "  - User object ID: ${UserObjectId}"
Write-Output "  - Using service endpoints instead of private endpoints: ${UseServiceEndpoints}"

$ResourceGroupName = "rg-copytest${ResourceNameMeronym}-${Environment}"
$Location = "westeurope"
$PrincipalType = "User"
$StorageAccountPrivateConnectivityMethod = "privateEndpoint"

if ($UseServiceEndpoints -Eq $True) {
    $StorageAccountPrivateConnectivityMethod = "serviceEndpoint"
}

Write-Output "`nCreating resource group ${ResourceGroupName}..."

az group create --name $ResourceGroupName --location $Location

Write-Output "`nCreating ""Owner"" role assignment for the user in resource group ${ResourceGroupName}..."

az role assignment create `
    --role "Owner" `
    --assignee-object-id $UserObjectId `
    --assignee-principal-type $PrincipalType `
    --scope "/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroupName}"

Write-Output "`nProvisioning Azure resources, this will take a few minutes..."

$Timestamp = Get-Date -Format "yyyyMMddHHmmss"

az deployment group create `
    --name "blobCopyTestDeployment${Timestamp}" `
    --resource-group $ResourceGroupName `
    --template-file ./bicep/main.bicep `
    --parameters `
        env=$Environment `
        resourceNameMeronym=$ResourceNameMeronym `
        opsObjectId=$UserObjectId `
        storageAccountPrivateConnectivityMethod=$StorageAccountPrivateConnectivityMethod
