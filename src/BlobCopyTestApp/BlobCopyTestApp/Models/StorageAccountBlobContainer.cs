namespace BlobCopyTestApp.Models;

using System.Text.Json.Serialization;

public class StorageAccountBlobContainer
{
    [JsonPropertyName("blobContainerName")]
    public string BlobContainerName { get; set; } = string.Empty;

    [JsonPropertyName("blobs")]
    public IList<string> Blobs { get; set; } = new List<string>();
}
