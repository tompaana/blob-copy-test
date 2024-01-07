# This script deploys the project to Azure
#
# Usage:
#
# .\DeployToAzure.ps1 -ResourceNameMeronym <resource name meronym> -Environment {dev, test, prod}
#
# Tested to work with Azure CLI version 2.46.0

Param(
    [Parameter(Mandatory, HelpMessage="Resource name meronym (lowercase alphanumeric, max length 2)")][string]$ResourceNameMeronym,
    [string]$Environment = "dev",
    [switch]$UseServiceEndpoints,
    [switch]$NoCode = $false
)

$ErrorActionPreference = "Stop"

if ($ResourceNameMeronym.Length -ne 2) {
    Write-Error "Invalid argument: Resource name meronym has invalid length - must be exactly 2"
    exit 1
}

Write-Output "" # Newline

try {
    Write-Output "Retrieving signed in user information..."
    $SignedInUserInformation = (az ad signed-in-user show | ConvertFrom-Json)

    Write-Output "Retrieving current subscription information..."
    $AccountInformation = (az account show | ConvertFrom-Json)
}
catch {
    Write-Error "Failed to retrieve the information of the signed in user or the account: ${_}"
    exit 1
}

$UserObjectId = $SignedInUserInformation.id
$UserDisplayName = $SignedInUserInformation.displayName
$UserPrincipalName = $SignedInUserInformation.userPrincipalName
$SubscriptionId = $AccountInformation.id
$SubscriptionName = $AccountInformation.name

if ($UserObjectId.Length -ne 36) {
    Write-Error "Failed to retrieve the information of the signed in user"
    exit 1
}

if ($SubscriptionId.Length -ne 36) {
    Write-Error "Failed to retrieve the Azure subscription information"
    exit 1
}

Write-Output "`nUsing the following subscription and identity to deploy the project:"
Write-Output "  - Subscription: ${SubscriptionName} (${SubscriptionId})"
Write-Output "  - Signed in user: ${UserDisplayName}`n    - User principal name: ${UserPrincipalName}`n    - Object ID: ${UserObjectId}"

$Confirmation = Read-Host "`nAre you sure you want to proceed (y/n)?"

if ($Confirmation.ToLower() -ne 'y' -and $Confirmation.ToLower() -ne 'yes') {
    Write-Output "Aborting"
    exit 0
}

Write-Output "`nStarting deployment..."

.\New-BicepDeployment.ps1 `
    -ResourceNameMeronym $ResourceNameMeronym `
    -Environment $Environment `
    -SubscriptionId $SubscriptionId `
    -UserObjectId $UserObjectId

Write-Output "`nUploading blobs..."

.\New-Blobs.ps1 -ResourceNameMeronym $ResourceNameMeronym -Environment $Environment

if ($NoCode -eq $false) {
    Write-Output "`nStarting code deployment..."

    .\New-CodeDeployment.ps1 -ResourceNameMeronym $ResourceNameMeronym -Environment $Environment

    Write-Output "`nFinished"
}
