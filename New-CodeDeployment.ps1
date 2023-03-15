# This script builds and deploys the app service code
#
# Usage:
#
# .\New-CodeDeployment.ps1 `
#       -ResourceNameMeronym <resource name meronym> `
#       -Environment <environment {dev, test, prod}, default is "dev">
#
# Tested to work with Azure CLI version 2.46.0

Param(
    [Parameter(Mandatory, HelpMessage="Resource name meronym (lowercase alphanumeric, max length 2)")][string]$ResourceNameMeronym,
    [string]$Environment = "dev",
    [switch]$NoBuild = $False, # If true, will not build source, but expects the source to be built (or packaged if -NoPackage is set to true)
    [switch]$NoPackage = $False # If true, will not build source nor package the source, but expects the packages to exist
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

$ResourceGroupName = "rg-copytest${ResourceNameMeronym}-${Environment}"
$AppServiceName = "app-copytest${ResourceNameMeronym}-${Environment}-westeurope"

$SourceRootPath = Join-Path -Path "." -ChildPath "src"
$AppServiceCodeRootPath = Join-Path -Path $SourceRootPath -ChildPath "BlobCopyTestApp"
$AppServiceCodeSolutionPath = Join-Path -Path $AppServiceCodeRootPath -ChildPath "BlobCopyTestApp.sln"
$BuildConfiguration = "Debug"
$AppServiceCodeBuildPath = Join-Path -Path $AppServiceCodeRootPath -ChildPath "BlobCopyTestApp"
$AppServiceCodeBuildPath = Join-Path -Path $AppServiceCodeBuildPath -ChildPath "bin"
$AppServiceCodeBuildPath = Join-Path -Path $AppServiceCodeBuildPath -ChildPath $BuildConfiguration
$AppServiceCodeBuildPath = Join-Path -Path $AppServiceCodeBuildPath -ChildPath "net6.0"
$AppServiceCodeBuildPath = Join-Path -Path $AppServiceCodeBuildPath -ChildPath "*"
$AppServiceCodeZipPackagePath = Join-Path -Path "." -ChildPath "BlobCopyTestApp.zip"

if ($NoBuild -or $NoPackage) {
    Write-Output "`nSkipping building source step..."
} else {
    Write-Output "`nRestoring packages..."
    dotnet restore $AppServiceCodeSolutionPath --interactive

    Write-Output "`nBuilding source..."

    dotnet publish $AppServiceCodeSolutionPath `
        --configuration $BuildConfiguration `
        --no-restore
}

if ($NoPackage) {
    Write-Output "`nSkipping package built source step..."
} else {
    Write-Output "`nPackaging built code..."

    Compress-Archive `
        -Path $AppServiceCodeBuildPath `
        -DestinationPath $AppServiceCodeZipPackagePath `
        -Force
}

Write-Output "`nDeploying code to app service ${AppServiceName}..."

az webapp deploy `
    --resource-group $ResourceGroupName `
    --name $AppServiceName `
    --type zip `
    --src-path $AppServiceCodeZipPackagePath `
    --clean true
