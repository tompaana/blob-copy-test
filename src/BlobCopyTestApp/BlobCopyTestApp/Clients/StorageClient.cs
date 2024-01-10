namespace BlobCopyTestApp.Clients;

using Azure;
using Azure.Identity;
using Azure.Storage;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Files.Shares;
using Azure.Storage.Files.Shares.Models;
using Azure.Storage.Sas;

public class StorageClient
{
    private ShareClient? _shareClient;

    public StorageClient()
    {
    }

    public static BlobServiceClient GetBlobServiceClient(string storageAccountName, string? storageAccountKey = null)
    {
        Uri accountEndpoint = new($"https://{storageAccountName}.blob.core.windows.net");

        if (string.IsNullOrWhiteSpace(storageAccountKey))
        {
            return new BlobServiceClient(accountEndpoint, new DefaultAzureCredential());
        }

        var credential = new StorageSharedKeyCredential(storageAccountName, storageAccountKey);
        return new BlobServiceClient(accountEndpoint, credential);
    }

    public static BlobContainerClient GetBlobContainerClient(string storageAccountName, string containerName, string? storageAccountKey = null)
    {
        Uri accountEndpoint = new($"https://{storageAccountName}.blob.core.windows.net/{containerName}");

        if (string.IsNullOrWhiteSpace(storageAccountKey))
        {
            return new BlobContainerClient(accountEndpoint, new DefaultAzureCredential());
        }

        var credential = new StorageSharedKeyCredential(storageAccountName, storageAccountKey);
        return new BlobContainerClient(accountEndpoint, credential);
    }

    public static AsyncPageable<BlobContainerItem> GetBlobContainersAsync(string storageAccountName, string? storageAccountKey = null)
    {
        return GetBlobServiceClient(storageAccountName, storageAccountKey).GetBlobContainersAsync();
    }

    public static AsyncPageable<BlobItem> GetBlobsAsync(string storageAccountName, string containerName, string? storageAccountKey = null)
    {
        BlobContainerClient blobContainerClient = GetBlobContainerClient(storageAccountName, containerName, storageAccountKey);
        return blobContainerClient.GetBlobsAsync();
    }

    public IList<string> GetFiles(string storageAccountName, string storageAccountKey, string shareName, string rootDirectory = "")
    {
        IList<string> filePaths = new List<string>();
        ShareClient shareClient = GetShareClient(storageAccountName, storageAccountKey, shareName);
        ShareDirectoryClient directoryClient = shareClient.GetDirectoryClient(string.Empty);
        var shareFileItems = directoryClient.GetFilesAndDirectories();

        foreach (var shareFileItem in shareFileItems)
        {
            if (shareFileItem.IsDirectory)
            {
                string path = Path.Combine(rootDirectory, shareFileItem.Name);
                ((List<string>)filePaths).AddRange(GetFiles(storageAccountName, storageAccountKey, shareName, path));
            }

            filePaths.Add(Path.Combine(rootDirectory, shareFileItem.Name));
        }

        return filePaths;
    }

    public static bool DeleteBlob(string storageAccountName, string containerName, string blobName, string? storageAccountKey = null)
    {
        BlobContainerClient blobContainerClient = GetBlobContainerClient(storageAccountName, containerName, storageAccountKey);
        BlobClient blobClient = blobContainerClient.GetBlobClient(blobName);
        return blobClient.DeleteIfExists();
    }

    public static async Task<int> DeleteBlobsAsync(string storageAccountName, string containerName, string blobPathPrefix, string? storageAccountKey = null)
    {
        BlobContainerClient blobContainerClient = GetBlobContainerClient(storageAccountName, containerName, storageAccountKey);
        var blobItems = blobContainerClient.GetBlobsAsync(prefix: blobPathPrefix);
        int deletedCount = 0;

        await foreach (BlobItem blobItem in blobItems)
        {
            BlobClient blobClient = blobContainerClient.GetBlobClient(blobItem.Name);

            if (await blobClient.DeleteIfExistsAsync())
            {
                deletedCount++;
            }
        }

        return deletedCount;
    }

    public static async Task<ShareFileCopyInfo> StartCopyBlobToFileShareAsync(
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
        StorageSharedKeyCredential credential = new(storageAccountName, storageAccountKey);
        Uri destinationUri = new($"https://{storageAccountName}.file.core.windows.net/{fileShareSas.ShareName}/{fileShareSas.FilePath}");

        ShareUriBuilder shareUriBuilder = new(destinationUri)
        {
            Sas = fileShareSas.ToSasQueryParameters(credential)
        };

        return shareUriBuilder.ToUri();
    }

    private ShareClient GetShareClient(string storageAccountName, string storageAccountKey, string shareName)
    {
        if (_shareClient == null || !_shareClient.Name.Equals(shareName))
        {
            Uri shareUri = new($"https://{storageAccountName}.file.core.windows.net/{shareName}");
            StorageSharedKeyCredential credential = new(storageAccountName, storageAccountKey);
            _shareClient = new ShareClient(shareUri, credential);
        }

        return _shareClient;
    }
}
