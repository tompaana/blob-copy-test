namespace BlobCopyTestApp.Api;

using System.Reflection;
using System.Text.Json;
using BlobCopyTestApp.Clients;
using BlobCopyTestApp.Models;
using Swashbuckle.AspNetCore.Annotations;

public static class HealthApi
{
    public static void RegisterHealthApi(this WebApplication app)
    {
        app.MapGet("/health",
        [SwaggerOperation(Summary = "Health status", Description = "To check if the app is alive and responding.")]
        () =>
        {
            return Results.Ok("OK");
        })
        .WithTags("Health")
        .Produces(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

        app.MapGet("/health/config",
        [SwaggerOperation(Summary = "App config", Description = "Checks the app status verifying settings and access to resources.")]
        async () =>
        {
            AppConfig appConfig = await GetAppConfigAsync(app.Environment, app.Configuration);

            if (appConfig.Status.Equals("OK"))
            {
                return Results.Ok(appConfig);
            }

            return Results.Problem(title: "Not healthy", detail: JsonSerializer.Serialize(appConfig), statusCode: 500);
        })
        .WithTags("Health")
        .Produces<AppConfig>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);
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
            PrivateConnectivityMethod = Environment.GetEnvironmentVariable("PRIVATE_CONNECTIVITY_METHOD"),
            BlobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX"),
            FileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX")
        };

        if (!string.IsNullOrWhiteSpace(appConfig.KeyVaultName)
            && !string.IsNullOrWhiteSpace(appConfig.FileShareStorageAccountNamePrefix))
        {
            KeyVaultClient keyVaultClient = new();

            try
            {
                appConfig.FileShareStorageAccountKeyLength =
                    (await keyVaultClient.GetSecretAsync($"{appConfig.FileShareStorageAccountNamePrefix}westeuropeStorageAccountKey")).Length;
            }
            catch (Exception)
            {
            }
        }

        return appConfig;
    }
}
