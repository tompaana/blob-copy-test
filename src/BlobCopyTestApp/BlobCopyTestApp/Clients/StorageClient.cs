using Azure.Identity;
using Azure.Storage;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Files.Shares;
using Azure.Storage.Files.Shares.Models;
using Azure.Storage.Sas;

namespace BlobCopyTestApp.Clients;

public class StorageClient
{
    public static async Task<ShareFileCopyInfo> CopyBlobToFileShareAsync(
        string blobStorageAccountName,
        string blobContainerName,
        string blobName,
        string fileShareStorageAccountName,
        string fileShareStorageAccountKey,
        string fileShareName,
        string filePath)
    {
        DateTime tokenExpiry = DateTime.UtcNow.AddMinutes(15);
        BlobSasPermissions blobSasPermissions = BlobSasPermissions.Read | BlobSasPermissions.Write;
        ShareFileSasPermissions shareFileSasPermissions = ShareFileSasPermissions.Create | ShareFileSasPermissions.Write;

        Uri blobUri = await GetBlobSasUriAsync(blobStorageAccountName, blobContainerName, blobName, tokenExpiry, blobSasPermissions);
        Uri fileSasUri = GetFileShareSasUri(fileShareStorageAccountName, fileShareStorageAccountKey, fileShareName, filePath, tokenExpiry, shareFileSasPermissions);

        ShareFileClient shareFileClient = new(fileSasUri);

        return await shareFileClient.StartCopyAsync(blobUri);
    }

    private static async Task<Uri> GetBlobSasUriAsync(
        string storageAccountName,
        string containerName,
        string blobName,
        DateTime expiresOn,
        BlobSasPermissions permissions)
    {
        BlobServiceClient blobServiceClient = new(
            new Uri($"https://{storageAccountName}.blob.core.windows.net"),
            new DefaultAzureCredential());

        BlobContainerClient blobContainerClient = blobServiceClient.GetBlobContainerClient(containerName);
        BlobClient blobClient = blobContainerClient.GetBlobClient(blobName);

        BlobSasBuilder blobSas = new()
        {
            BlobContainerName = blobClient.BlobContainerName,
            BlobName = blobClient.Name,
            Resource = "b",
            ExpiresOn = expiresOn,
        };

        blobSas.SetPermissions(permissions);

        UserDelegationKey userDelegationKey = await blobServiceClient.GetUserDelegationKeyAsync(null, expiresOn);

        BlobUriBuilder blobUriBuilder = new(blobClient.Uri)
        {
            Sas = blobSas.ToSasQueryParameters(userDelegationKey, blobServiceClient.AccountName)
        };

        return blobUriBuilder.ToUri();
    }

    private static Uri GetFileShareSasUri(
        string storageAccountName,
        string storageAccountKey,
        string shareName,
        string filePath,
        DateTime expiresOn,
        ShareFileSasPermissions permissions)
    {
        ShareSasBuilder fileShareSas = new()
        {
            ShareName = shareName,
            FilePath = filePath,
            Resource = "f",
            ExpiresOn = expiresOn,
        };

        fileShareSas.SetPermissions(permissions);
        StorageSharedKeyCredential credentials = new(storageAccountName, storageAccountKey);
        Uri destinationUri = new($"https://{storageAccountName}.file.core.windows.net/{fileShareSas.ShareName}/{fileShareSas.FilePath}");

        ShareUriBuilder shareUriBuilder = new(destinationUri)
        {
            Sas = fileShareSas.ToSasQueryParameters(credentials)
        };

        return shareUriBuilder.ToUri();
    }
}
