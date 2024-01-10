namespace BlobCopyTestApp.Api;

using System.ComponentModel.DataAnnotations;
using Azure;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Files.Shares.Models;
using BlobCopyTestApp.Clients;
using BlobCopyTestApp.Models;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;

public static class StorageApi
{
    public enum Location
    {
        PrimaryLocation = 0,
        SecondaryLocation = 1,
    }

    public enum StorageAccountType
    {
        Blob = 0,
        FileShare = 1,
    }

    private const string BlobContainerName = "copytest";
    private const string FileShareName = "copytest";
    private const string BlobName = "test.txt";
    private const string CopiedBlobName = "test-from-{0}.txt"; // Source location as param
    private const string StorageAccountKeySecretName = "{0}StorageAccountKey"; // Storage account name as param

    public static string? LocationEnumToString(Location location)
    {
        string? primaryLocation = Environment.GetEnvironmentVariable("PRIMARY_LOCATION");
        string? secondaryLocation = Environment.GetEnvironmentVariable("SECONDARY_LOCATION");
        return (location == Location.PrimaryLocation) ? primaryLocation : secondaryLocation;
    }

    public static void RegisterStorageApi(this WebApplication app)
    {
        app.MapGet("/list/all",
        [SwaggerOperation(Summary = "Lists all storage accounts and their content", Description = "Lists all storage accounts and their content")]
        async () =>
        {
            List<StorageAccountContent> storageAccountContents = new();

            try
            {
                storageAccountContents.AddRange(await ListBlobsAsync());
                storageAccountContents.AddRange(await ListFileSharesAsync());
            }
            catch (Exception e)
            {
                return Results.Problem(title: $"Failed to list storage accounts and their content", detail: e.Message, statusCode: StatusCodes.Status500InternalServerError);
            }

            return Results.Ok(storageAccountContents);
        })
        .WithTags("Storage")
        .Produces<IList<StorageAccountContent>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

        app.MapGet("/list/blobs",
        [SwaggerOperation(Summary = "Lists blobs", Description = "List blobs in storage accounts")]
        async () =>
        {
            IList<StorageAccountContent>? storageAccountContents = null;

            try
            {
                storageAccountContents = await ListBlobsAsync();
            }
            catch (Exception e)
            {
                return Results.Problem(title: $"Failed to list blobs", detail: e.Message, statusCode: StatusCodes.Status500InternalServerError);
            }

            return Results.Ok(storageAccountContents);
        })
        .WithTags("Storage")
        .Produces<IList<StorageAccountContent>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

        app.MapGet("/list/files",
        [SwaggerOperation(Summary = "Lists files in file shares", Description = "List files in storage account file shares")]
        async () =>
        {
            IList<StorageAccountContent>? storageAccountContents = null;

            try
            {
                storageAccountContents = await ListFileSharesAsync();
            }
            catch (Exception e)
            {
                return Results.Problem(title: $"Failed to list files", detail: e.Message, statusCode: StatusCodes.Status500InternalServerError);
            }

            return Results.Ok(storageAccountContents);
        })
        .WithTags("Storage")
        .Produces<IList<StorageAccountContent>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);


        app.MapPost("/copy",
        [SwaggerOperation(Summary = "Copies blob to file share", Description = "Copies a blob from a storage account to a file share using the given locations (regions) e.g., from \"westeurope\" to \"swedencentral\".")]
        async ([FromQuery][Required] string sourceLocation, [FromQuery][Required] string destinationLocation) =>
        {
            CopyResult copyResult;

            try
            {
                copyResult = await CopyAsync(sourceLocation, destinationLocation, app.Logger);
            }
            catch (Exception e)
            {
                return Results.Problem(title: $"Failed to copy", detail: e.Message, statusCode: StatusCodes.Status500InternalServerError);
            }

            return Results.Ok(copyResult);
        })
        .WithTags("Storage")
        .Produces<CopyResult>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

        app.MapPost("/copy/all",
        [SwaggerOperation(Summary = "Copies blobs to file shares", Description = "Copies a blob from a storage account to a file share using all the possible location combinations.")]
        async () =>
        {
            Location[] locations = { Location.PrimaryLocation, Location.SecondaryLocation };
            IList<CopyResult> copyResults = new List<CopyResult>();

            foreach (Location sourceLocation in locations)
            {
                foreach (Location destinationLocation in locations)
                {
                    try
                    {
                        copyResults.Add(await CopyAsync(sourceLocation, destinationLocation, app.Logger));
                    }
                    catch (Exception e)
                    {
#pragma warning disable CS8601 // Possible null reference assignment.
                        copyResults.Add(new CopyResult()
                        {
                            SourceLocation = LocationEnumToString(sourceLocation),
                            DestinationLocation = LocationEnumToString(destinationLocation),
                            CopyStatus = Azure.Storage.Files.Shares.Models.CopyStatus.Failed,
                            Message = e.Message
                        });
#pragma warning restore CS8601 // Possible null reference assignment.
                    }
                }
            }

            return Results.Ok(copyResults);
        })
        .WithTags("Storage")
        .Produces<IList<CopyResult>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

    }

    private static async Task<IList<StorageAccountContent>> ListBlobsAsync()
    {
        IList<StorageAccountContent> storageAccountContents = new List<StorageAccountContent>();
        IList<string> storageAccountNames = GetStorageAccountNames(StorageAccountType.Blob);

        foreach (string storageAccountName in storageAccountNames)
        {
            StorageAccountContent storageAccountContent = new()
            {
                StorageAccountName = storageAccountName,
                BlobContainers = new List<StorageAccountBlobContainer>()
            };

            AsyncPageable<BlobContainerItem> containers = StorageClient.GetBlobContainersAsync(storageAccountName);

            await foreach (BlobContainerItem container in containers)
            {
                StorageAccountBlobContainer storageAccountBlobContainer = new()
                {
                    BlobContainerName = container.Name
                };

                AsyncPageable<BlobItem> blobs = StorageClient.GetBlobsAsync(storageAccountName, container.Name);

                await foreach (BlobItem blob in blobs)
                {
                    storageAccountBlobContainer.Blobs.Add(blob.Name);
                }

                storageAccountContent.BlobContainers.Add(storageAccountBlobContainer);
            }

            storageAccountContents.Add(storageAccountContent);
        }

        return storageAccountContents;
    }

    private static async Task<IList<StorageAccountContent>> ListFileSharesAsync()
    {
        IList<StorageAccountContent> storageAccountContents = new List<StorageAccountContent>();
        IList<string> storageAccountNames = GetStorageAccountNames(StorageAccountType.FileShare);

        foreach (string storageAccountName in storageAccountNames)
        {
            StorageAccountContent storageAccountContent = new()
            {
                StorageAccountName = storageAccountName,
                FileShares = new List<StorageAccountFileShare>()
            };

            StorageAccountFileShare fileShare = new()
            {
                FileShareName = FileShareName
            };

            KeyVaultClient keyVaultClient = new();
            string keySecretName = string.Format(StorageAccountKeySecretName, storageAccountName);
            string storageAccountKey = await keyVaultClient.GetSecretAsync(keySecretName);
            StorageClient storageClient = new();
            fileShare.Files = storageClient.GetFiles(storageAccountName, storageAccountKey, fileShare.FileShareName, string.Empty);

            storageAccountContent.FileShares.Add(fileShare);
            storageAccountContents.Add(storageAccountContent);
        }

        return storageAccountContents;
    }

    public static async Task<CopyResult> CopyAsync(Location sourceLocation, Location destinationLocation, ILogger logger)
    {
        string? from = LocationEnumToString(sourceLocation);
        string? to = LocationEnumToString(destinationLocation);

        if (string.IsNullOrEmpty(from) || string.IsNullOrEmpty(to))
        {
            throw new InvalidOperationException("Failed to resolve locations");
        }

        return await CopyAsync(from, to, logger);
    }

    public static async Task<CopyResult> CopyAsync(string from, string to, ILogger logger)
    {

        string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
        string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

        if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix)
            || string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
        {
            throw new InvalidOperationException("Missing environment values for storage account name prefixes");
        }

        string blobStorageAccountName = $"{blobStorageAccountNamePrefix}{from}";
        string fileShareStorageAccountName = $"{fileShareStorageAccountNamePrefix}{to}";
        string destinationFilePath = string.Format(CopiedBlobName, from);
        string fileShareStorageAccountKeySecretName = string.Format(StorageAccountKeySecretName, fileShareStorageAccountName);
        string? fileShareStorageAccountKey;

        CopyResult copyResult = new()
        {
            SourceLocation = from,
            SourceStorageAccountName = blobStorageAccountName,
            DestinationLocation = to,
            DestinationStorageAccountName = fileShareStorageAccountName
        };

        try
        {
            KeyVaultClient keyVaultClient = new();
            fileShareStorageAccountKey = await keyVaultClient.GetSecretAsync(fileShareStorageAccountKeySecretName);
        }
        catch (Exception e)
        {
            copyResult.Message = $"Failed to retrieve file share storage account key by secret name {fileShareStorageAccountKeySecretName}: {e.Message}";
            return copyResult;
        }

        ShareFileCopyInfo? shareFileCopyInfo = null;

        try
        {
            shareFileCopyInfo = await StorageClient.StartCopyBlobToFileShareAsync(
                blobStorageAccountName,
                BlobContainerName,
                BlobName,
                fileShareStorageAccountName,
                fileShareStorageAccountKey,
                FileShareName,
                destinationFilePath);
        }
        catch (RequestFailedException e)
        {
            copyResult.StatusCode = e.Status;
            copyResult.Message = $"Failed to copy from {from} to {to}: {e.Message}";
            logger.LogError(copyResult.Message);
        }
        catch (Exception e)
        {
            copyResult.Message = $"Failed to copy from {from} to {to}: {e.Message}";
            logger.LogError(copyResult.Message);
        }

        copyResult.CopyStatus = (shareFileCopyInfo == null)
            ? Azure.Storage.Files.Shares.Models.CopyStatus.Failed
            : shareFileCopyInfo.CopyStatus;

        copyResult.StatusCode = 201;
        copyResult.Message = "Copy operation appears successful or was successfully started";
        logger.LogInformation(copyResult.Message);
        return copyResult;
    }

    private static IList<string> GetStorageAccountNames(StorageAccountType storageAccountType)
    {
        string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
        string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

        if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix)
            || string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
        {
            throw new InvalidOperationException("Missing environment values for storage account name prefixes");
        }

        string storageAccountNamePrefix = (storageAccountType == StorageAccountType.Blob)
            ? blobStorageAccountNamePrefix : fileShareStorageAccountNamePrefix;

        Location[] locations = { Location.PrimaryLocation, Location.SecondaryLocation };
        IList<string> storageAccountNames = new List<string>();

        foreach (Location location in locations)
        {
            storageAccountNames.Add($"{storageAccountNamePrefix}{LocationEnumToString(location)}");
        }

        return storageAccountNames;
    }
}
