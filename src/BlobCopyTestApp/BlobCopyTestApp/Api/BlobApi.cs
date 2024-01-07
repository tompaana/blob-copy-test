namespace BlobCopyTestApp.Api;

using Azure.Storage.Blobs.Models;
using Azure;
using BlobCopyTestApp.Clients;
using BlobCopyTestApp.Models;
using Swashbuckle.AspNetCore.Annotations;

public static class BlobApi
{
    public enum Location
    {
        PrimaryLocation = 0,
        SecondaryLocation = 1,
    }

    public static string? LocationEnumToString(Location location)
    {
        string? primaryLocation = Environment.GetEnvironmentVariable("PRIMARY_LOCATION");
        string? secondaryLocation = Environment.GetEnvironmentVariable("SECONDARY_LOCATION");
        return (location == Location.PrimaryLocation) ? primaryLocation : secondaryLocation;
    }

    public static void RegisterBlobApi(this WebApplication app)
    {
        app.MapGet("/blobs/list",
        [SwaggerOperation(Summary = "Lists blobs", Description = "List blobs in storage accounts")]
        async () =>
        {
            IList<StorageAccountContent> storageAccountContents = null;

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
        .WithTags("Blobs")
        .Produces<IList<StorageAccountContent>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);
    }

    private static async Task<IList<StorageAccountContent>> ListBlobsAsync()
    {
        IList<StorageAccountContent> storageAccountContents = new List<StorageAccountContent>();
        IList<string> storageAccountNames = GetStorageAccountNames(true);

        foreach (string storageAccountName in storageAccountNames)
        {
            StorageAccountContent storageAccountContent = new()
            {
                StorageAccountName = storageAccountName
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

    private static IList<string> GetStorageAccountNames(bool blobStoragesOnly)
    {
        string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
        string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

        if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix)
            || string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
        {
            throw new InvalidOperationException("Missing environment values for storage account name prefixes");
        }

        IList<string> storageAccountNames = new List<string>();
        IList<string> storageAccountNamePrefixes = new List<string>() { blobStorageAccountNamePrefix };

        if (!blobStoragesOnly)
        {
            storageAccountNamePrefixes.Add(fileShareStorageAccountNamePrefix);
        }

        Location[] locations = { Location.PrimaryLocation, Location.SecondaryLocation };

        foreach (string storageAccountNamePrefix in storageAccountNamePrefixes)
        {
            foreach (Location location in locations)
            {
                storageAccountNames.Add($"{storageAccountNamePrefix}{LocationEnumToString(location)}");
            }
        }

        return storageAccountNames;
    }
}
