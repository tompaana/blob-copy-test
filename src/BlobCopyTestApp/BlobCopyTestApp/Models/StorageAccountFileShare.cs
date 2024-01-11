namespace BlobCopyTestApp.Models;

using System.Text.Json.Serialization;

public class StorageAccountFileShare
{
    [JsonPropertyName("fileShareName")]
    public string FileShareName { get; set; } = string.Empty;

    [JsonPropertyName("files")]
    public IList<string> Files { get; set; } = new List<string>();
}
