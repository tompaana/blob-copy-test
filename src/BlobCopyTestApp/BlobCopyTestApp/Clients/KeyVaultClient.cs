using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace BlobCopyTestApp.Clients;

public class KeyVaultClient
{
    private SecretClient? _secretClient;

    public async Task<string> GetSecretAsync(string secretName)
    {
        KeyVaultSecret keyVaultSecret = await GetSecretClient().GetSecretAsync(secretName);
        return keyVaultSecret.Value;
    }

    private SecretClient GetSecretClient()
    {
        if (_secretClient == null)
        {
            string? keyVaultName = Environment.GetEnvironmentVariable("KEY_VAULT_NAME");
            string keyVaultUri = $"https://{keyVaultName}.vault.azure.net";
            _secretClient = new SecretClient(new Uri(keyVaultUri), new DefaultAzureCredential());
        }

        return _secretClient;
    }
}
