# This script uploads blobs to storage accounts
#
# Usage:
#
# .\New-Blobs.ps1 `
#       -ResourceNameMeronym <resource name meronym> `
#       -Environment <environment {dev, test, prod}, default is "dev">
#
# Tested to work with Azure CLI version 2.56.0

Param(
    [Parameter(Mandatory, HelpMessage="Resource name meronym (lowercase alphanumeric, max length 2)")][string]$ResourceNameMeronym,
    [string]$Environment = "dev"
)

if ($ResourceNameMeronym.Length -ne 2) {
    Write-Error "Invalid argument: Resource name meronym has invalid length - must be exactly 2"
    exit 1
}

if ($Environment -ne "dev" -and $Environment -ne "test" -and $Environment -ne "prod") {
    Write-Error "Invalid argument: Environment given was ""${Environment}"", but the valid values are: ""dev"", ""test"" or ""prod"""
    exit 1
}

$ResourceGroupName = "rg-copytest${ResourceNameMeronym}-${Environment}"
$BlobStorageAccounts = @("stctb${ResourceNameMeronym}${Environment}westeurope", "stctb${ResourceNameMeronym}${Environment}swedencentral")
$MyIp = (Invoke-WebRequest -Uri "https://api.ipify.org/").Content
$ContainerName = "copytest"
$FileToUpload = ".\assets\test.txt"
$DestinationBlobName = "test.txt"

foreach ($BlobStorageAccount in $BlobStorageAccounts) {
    Write-Output "`nWhitelisting IP address (${MyIp}) to allow access to storage account ${BlobStorageAccount}..."

    az storage account network-rule add `
        --account-name $BlobStorageAccount `
        --action Allow `
        --ip-address $MyIp `
        --resource-group $ResourceGroupName
}

$SleepSeconds = 15
Write-Output "`nSleeping ${SleepSeconds} seconds to allow whitelisting to take an effect..."
Start-Sleep -Seconds $SleepSeconds

foreach ($BlobStorageAccount in $BlobStorageAccounts) {
    Write-Output "`nUploading file ${FileToUpload} to container ${ContainerName} in storage account ${BlobStorageAccount}..."

    az storage blob upload `
        --account-name $BlobStorageAccount `
        --auth-mode login `
        --container-name $ContainerName `
        --file $FileToUpload `
        --name $DestinationBlobName
}
