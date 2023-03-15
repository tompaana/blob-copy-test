using Azure.Storage.Files.Shares.Models;
using BlobCopyTestApp;
using Swashbuckle.AspNetCore.Annotations;

const string BlobContainerName = "copytest";
const string FileShareName = "copytest";
const string BlobName = "test.txt";

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", true, true)
    .AddEnvironmentVariables();

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.EnableAnnotations();
});

var app = builder.Build();

app.UseRouting();
app.UseSwagger();
app.UseSwaggerUI();

app.UseEndpoints(endpoints =>
{
    endpoints.MapGet("/", context => {
        context.Response.Redirect("swagger");
        return Task.CompletedTask;
    });
});

app.MapGet("/check",
    [SwaggerOperation(Summary = "Check app status", Description = "Checks the app status verifying settings and access to resources.")]
    async () =>
    {
        var results = await CheckAsync();
        return Results.Ok(results);
    }).Produces<IList<string>>(StatusCodes.Status200OK);

app.MapPost("/copy",
    [SwaggerOperation(Summary = "Copy blob to file share", Description = "Copies a blob from a storage account to a file share using the given locations (regions) e.g., from \"westeurope\" to \"swedencentral\".")]
    async (string from, string to) =>
    {
        IList<string> results = new List<string>();

        try
        {
            results = await CopyAsync(from, to);
        }
        catch (Exception e)
        {
            results.Add($"Failed to copy: {e.Message} - {e}");
        }

        return Results.Ok(results);
    }).Produces<IList<string>>(StatusCodes.Status200OK);


static async Task<IList<string>> CopyAsync(string from, string to)
{
    IList<string> results = new List<string>();
    string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
    string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

    if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix)
        || string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
    {
        throw new InvalidOperationException("Missing environment values");
    }

    string destinationFilePath = $"test-from-{from}.txt";
    string? fileShareStorageAccountKey = null;

    try
    {
        KeyVaultClient keyVaultClient = new();
        fileShareStorageAccountKey = await keyVaultClient.GetSecretAsync($"{fileShareStorageAccountNamePrefix}{to}Key");
        results.Add($"Retrieved file share storage account key with length {fileShareStorageAccountKey.Length} from Key Vault");
    }
    catch (Exception e)
    {
        results.Add($"Failed to retrieve file share storage account key: {e.Message} - {e}");
        return results;
    }

    ShareFileCopyInfo? shareFileCopyInfo = null;
    string blobStorageAccountName = $"{blobStorageAccountNamePrefix}{from}";
    string fileShareStorageAccountName = $"{fileShareStorageAccountNamePrefix}{to}";
    results.Add($"Copying from {blobStorageAccountName} to {fileShareStorageAccountName}...");

    try
    {
        shareFileCopyInfo = await StorageClient.CopyBlobToFileShareAsync(
            blobStorageAccountName,
            BlobContainerName,
            BlobName,
            fileShareStorageAccountName,
            fileShareStorageAccountKey,
            FileShareName,
            destinationFilePath);

        results.Add($"Copy operation from {blobStorageAccountName} to {fileShareStorageAccountName} appears to have succeeded");
    }
    catch (Exception e)
    {
        results.Add($"Failed to copy blob: {e.Message} - {e}");
    }

    if (shareFileCopyInfo != null)
    {
        results.Add($"Copy status: {shareFileCopyInfo.CopyStatus}");
    }

    return results;
}

static async Task<IList<string>> CheckAsync()
{
    IList<string> results = new List<string>();

    string? keyVaultName = Environment.GetEnvironmentVariable("KEY_VAULT_NAME");
    string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
    string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

    if (string.IsNullOrWhiteSpace(keyVaultName))
    {
        results.Add("Key Vault name missing!");
    }
    else
    {
        results.Add($"Key Vault name: {keyVaultName}");
    }

    if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix))
    {
        results.Add("Blob storage account name prefix missing!");
    }
    else
    {
        results.Add($"Blob storage account name prefix: {blobStorageAccountNamePrefix}");
    }

    if (string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
    {
        results.Add("File share storage account name prefix missing!");
    }
    else
    {
        results.Add($"File share storage account name prefix: {fileShareStorageAccountNamePrefix}");
    }

    string? fileShareStorageAccountKey = string.Empty;

    try
    {
        KeyVaultClient keyVaultClient = new();
        fileShareStorageAccountKey = await keyVaultClient.GetSecretAsync($"{fileShareStorageAccountNamePrefix}westeuropeKey");
    }
    catch (Exception e)
    {
        results.Add($"Failed to retrieve a file share storage key from Key Vault: {e}");
    }

    if (string.IsNullOrWhiteSpace(fileShareStorageAccountKey))
    {
        results.Add("File share storage account key is empty!");
    }
    else
    {
        results.Add($"File share storage account key: {fileShareStorageAccountKey.Substring(0, 4)}...");
    }

    return results;
}

app.Run();
