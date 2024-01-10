# Tested to work with Azure CLI version 2.56.0 and storage-preview extension version 1.0.0b1.
Param(
    [Parameter(Mandatory, HelpMessage="Resource group name")][string]$ResourceGroupName,
    [Parameter(Mandatory, HelpMessage="Storage account name")][string]$StorageAccountName,
    [Parameter(Mandatory, HelpMessage="IP ranges file path")][string]$IpRangesFilePath
)

$JsonContent = Get-Content $IpRangesFilePath | Out-String | ConvertFrom-Json
$AddressPrefixes = ""

foreach ($AddressPrefix in $JsonContent.addressPrefixes) {
    if ($AddressPrefix -Match ":") {
        Write-Output "Skipping IPv6 address ${AddressPrefix}..."
        continue
    }

    if ($AddressPrefix.StartsWith("10.") `
        -or $AddressPrefix.StartsWith("172.16") `
        -or $AddressPrefix.StartsWith("172.17") `
        -or $AddressPrefix.StartsWith("172.18") `
        -or $AddressPrefix.StartsWith("172.30") `
        -or $AddressPrefix.StartsWith("172.31") `
        -or $AddressPrefix.StartsWith("192.168")) {
        Write-Output "Skipping private IP address ${AddressPrefix}..."
        continue
    }

    Write-Output "Adding IP to list ${AddressPrefix}..."

    if ($AddressPrefixes.Length -eq 0) {
        $AddressPrefixes = $AddressPrefix
    } else {
        $AddressPrefixes = $AddressPrefixes, $AddressPrefix -join " "
    }
}

Write-Output "`nAdresses to whitelist: ${AddressPrefixes}"

Write-Output "`nWhitelisting the list of IPs/ranges in storage account network rules..."

$Command = "az storage account network-rule add --account-name $StorageAccountName --action Allow --ip-address $AddressPrefixes --resource-group $ResourceGroupName"
Invoke-Expression $Command

Write-Output "`nFinished"
