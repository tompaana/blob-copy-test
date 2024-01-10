namespace BlobCopyTestApp.Models;

using System.Text.Json.Serialization;

public class AppConfig
{
    [JsonPropertyName("buildVersion")]
    public string? BuildVersion { get; set; } = string.Empty;

    [JsonPropertyName("environmentName")]
    public string? EnvironmentName { get; set; } = null;

    [JsonPropertyName("logLevel")]
    public string? LogLevel { get; set; } = null;

    [JsonPropertyName("keyVaultName")]
    public string? KeyVaultName { get; set; } = string.Empty;

    [JsonPropertyName("blobStorageAccountNamePrefix")]
    public string? BlobStorageAccountNamePrefix { get; set; } = string.Empty;

    [JsonPropertyName("fileShareStorageAccountNamePrefix")]
    public string? FileShareStorageAccountNamePrefix { get; set; } = string.Empty;

    [JsonPropertyName("fileShareStorageAccountKeyLength")]
    public int FileShareStorageAccountKeyLength { get; set; } = -1;

    [JsonPropertyName("status")]
    public string Status
    {
        get
        {
            if (string.IsNullOrWhiteSpace(KeyVaultName)
                || string.IsNullOrWhiteSpace(BlobStorageAccountNamePrefix)
                || string.IsNullOrWhiteSpace(FileShareStorageAccountNamePrefix)
                || FileShareStorageAccountKeyLength <= 0)
            {
                return "NOK";
            }

            return "OK";
        }
    }
}
