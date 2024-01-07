namespace BlobCopyTestApp.Models;

using System.Text.Json.Serialization;

public class StorageAccountContent
{
    [JsonPropertyName("storageAccountName")]
    public string StorageAccountName { get; set; } = string.Empty;

    [JsonPropertyName("blobContainers")]
    public IList<StorageAccountBlobContainer> BlobContainers { get; set; } = new List<StorageAccountBlobContainer>();
}
