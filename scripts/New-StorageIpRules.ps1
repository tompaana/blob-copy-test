Param(
    [Parameter(Mandatory, HelpMessage="Resource group name")][string]$ResourceGroupName,
    [Parameter(Mandatory, HelpMessage="Storage account name")][string]$StorageAccountName,
    [Parameter(Mandatory, HelpMessage="IP ranges file path")][string]$IpRangesFilePath
)

$JsonContent = Get-Content $IpRangesFilePath | Out-String | ConvertFrom-Json

foreach ($AddressPrefix in $JsonContent.addressPrefixes) {
    if ($AddressPrefix -Match ":") {
        Write-Output "`nSkipping IPv6 address prefix ${AddressPrefix}..."
        continue
    }

    Write-Output "`nAdding rule to allow access from IP range ${AddressPrefix}..."

    az storage account network-rule add `
        --account-name $StorageAccountName `
        --action Allow `
        --ip-address $AddressPrefix `
        --resource-group $ResourceGroupName
}

Write-Output "`nFinished"
