Param(
    [Parameter(Mandatory, HelpMessage="Resource group name")][string]$ResourceGroupName,
    [Parameter(Mandatory, HelpMessage="Storage account name")][string]$StorageAccountName,
    [Parameter(Mandatory, HelpMessage="IP ranges file path")][string]$IpRangesFilePath
)

$JsonContent = Get-Content $IpRangesFilePath | Out-String | ConvertFrom-Json
$AddressPrefixes = ""

foreach ($AddressPrefix in $JsonContent.addressPrefixes) {
    if ($AddressPrefix -Match ":") {
        Write-Output "Skipping IPv6 address prefix ${AddressPrefix}..."
        continue
    }

    Write-Output "Adding IP to list ${AddressPrefix}..."

    if ($AddressPrefixes.Length -eq 0) {
        $AddressPrefixes = $AddressPrefix
    } else {
        $AddressPrefixes = $AddressPrefixes, $AddressPrefix -join " "
    }
}

Write-Output "Whitelisting the list of IPs/ranges in storage account network rules..."

az storage account network-rule add `
    --account-name $StorageAccountName `
    --action Allow `
    --ip-address $AddressPrefixes `
    --resource-group $ResourceGroupName

Write-Output "`nFinished"
