using System.Reflection;
using System.Text.Json;
using Azure.Storage.Files.Shares.Models;
using BlobCopyTestApp.Clients;
using BlobCopyTestApp.Models;
using Swashbuckle.AspNetCore.Annotations;

const string BlobContainerName = "copytest";
const string FileShareName = "copytest";
const string BlobName = "test.txt";

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
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

app.MapGet("/health",
    [SwaggerOperation(Summary = "App health status", Description = "Checks the app status verifying settings and access to resources.")]
    async () =>
    {
        AppConfig appConfig = await GetAppConfigAsync(app.Environment, app.Configuration);

        if (appConfig.Status.Equals("OK"))
        {
            return Results.Ok(appConfig);
        }

        return Results.Problem(title: "Not healthy", detail: JsonSerializer.Serialize(appConfig), statusCode: 500);
    })
    .Produces<AppConfig>(StatusCodes.Status200OK)
    .Produces(StatusCodes.Status500InternalServerError);

app.MapPost("/copy",
    [SwaggerOperation(Summary = "Copies blob to file share", Description = "Copies a blob from a storage account to a file share using the given locations (regions) e.g., from \"westeurope\" to \"swedencentral\".")]
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

static async Task<AppConfig> GetAppConfigAsync(IHostEnvironment environment, IConfiguration configuration)
{
    AssemblyInformationalVersionAttribute? versionAttribute = Assembly.GetExecutingAssembly()
        .GetCustomAttributes(typeof(AssemblyInformationalVersionAttribute), false)
        .FirstOrDefault() as AssemblyInformationalVersionAttribute;

    AppConfig appConfig = new()
    {
        BuildVersion = versionAttribute?.InformationalVersion,
        EnvironmentName = environment.EnvironmentName,
        LogLevel = configuration["Logging:LogLevel:Default"],
        KeyVaultName = Environment.GetEnvironmentVariable("KEY_VAULT_NAME"),
        BlobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX"),
        FileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX")
    };

    if (!string.IsNullOrWhiteSpace(appConfig.KeyVaultName)
        && !string.IsNullOrWhiteSpace(appConfig.FileShareStorageAccountNamePrefix))
    {
        KeyVaultClient keyVaultClient = new();
        appConfig.FileShareStorageAccountKeyLength =
            (await keyVaultClient.GetSecretAsync($"{appConfig.FileShareStorageAccountNamePrefix}westeuropeKey")).Length;
    }

    return appConfig;
}

app.Run();
