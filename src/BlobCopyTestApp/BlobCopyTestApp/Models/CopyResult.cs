namespace BlobCopyTestApp.Models;

using System.Text.Json.Serialization;
using Azure.Storage.Files.Shares.Models;

public class CopyResult
{
    [JsonPropertyName("sourceLocation")]
    public string SourceLocation { get; set; } = string.Empty;

    [JsonPropertyName("sourceStorageAccountName")]
    public string SourceStorageAccountName { get; set; } = string.Empty;

    [JsonPropertyName("destinationLocation")]
    public string DestinationLocation { get; set; } = string.Empty;

    [JsonPropertyName("destinationStorageAccountName")]
    public string DestinationStorageAccountName { get; set; } = string.Empty;

    [JsonPropertyName("copyStatus")]
    public CopyStatus CopyStatus { get; set; } = CopyStatus.Failed;

    [JsonPropertyName("statusCode")]
    public int? StatusCode { get; set; } = null;

    [JsonPropertyName("message")]
    public string? Message { get; set; } = null;
}
