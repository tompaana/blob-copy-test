# Blob copy test

> **Warning**
>
> This is a test project to identify possible problems with cross-region data copying, and to find solutions/workarounds. This is not secure piece of software and running it exposes sensitive information deliberately for troubleshooting purposes.
>
> *Viewer discretion is advised.*

The solution will deploy two, peered virtual networks in different locations (`westeurope` and `swedencentral`) both containing a blob storage and a file share storage so 4 storage accounts in total. None of the storages allow public internet access, but use private endpoints instead. A very simple app service with a Swagger UI is provided to test copying blobs from different accounts to different file shares.

## Prerequisites

* Azure subscription
* [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with [Bicep support](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install#azure-cli)
* [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
* [.NET 6](https://dotnet.microsoft.com/download/dotnet/6.0)

Tested in Windows with Azure CLI version 2.46.0.

## Scripts to install/deploy

PowerShell scripts provided to install/deploy the project:

| Script | Description |
| ------ | ----------- |
| `DeployToAzure.ps1` | Full install/deployment. Runs all the scripts below in the specified order. |
| `New-BicepDeployment.ps1` | Creates a resource group and provisions Azure resources specified in the main Bicep template (`/bicep/main.bicep`). |
| `New-Blobs.ps1` | Uploads the test blobs (to copy later) to storage accounts. |
| `New-CodeDeployment.ps1` | Deploys the app code (with Swagger) to the app service. |

All the scripts are (more or less) idempotent. Note that in most cases the scripts will not stop executing when an error occurs. The "sub" scripts can be run independently to save time if any of the phases should fail.

## Deploying the solution

1. Login with Azure CLI:

    ```powershell
    az login
    ```

    > Verify that you have the right subscription selected with command `az account show`. Change the subscription with command `az account set --subscription <subscription ID>` if necessary.

1. Run the main script:

    ```powershell
    .\DeployToAzure.ps1 -ResourceNameMeronym <two alphanumeric, lowercase characters>
    ```

    > The resource name meronym is required for unique resource names should this solution ever be deployed by more than one person.

    > **Note**
    >
    > Errors can happen and if they do, rather than starting all over, you can continue from a point closer to the failure point by running the "sub" scripts seprately:
    >
    > ```powershell
    > .\New-BicepDeployment.ps1 -ResourceNameMeronym <two alphanumeric, lowercase characters>
    > ```
    >
    > ```powershell
    > .\New-Blobs.ps1 -ResourceNameMeronym <two alphanumeric, lowercase characters>
    > ```
    >
    > ```powershell
    > .\New-CodeDeployment.ps1 -ResourceNameMeronym <two alphanumeric, lowercase characters>
    > ```

1. If all goes well, head to the [Azure portal](https://portal.azure.com) and find the app service and launch it in the browser

1. Copy some blobs using the Swagger UI (or a tool that can do POST calls of your choice)!

## Observed copy results

**The app service issuing the copy command resides in location `westeurope`.** This is the likely culprit for the observed failing case.

| Source blob location | Destination file share location | Copy result |
| -- | -- | -- |
| `westeurope` | `westeurope` | OK |
| `westeurope` | `swedencentral` | OK |
| `swedencentral` | `westeurope` | FAILS with error `CannotVerifyCopySource` |
| `swedencentral` | `swedencentral` | OK |
