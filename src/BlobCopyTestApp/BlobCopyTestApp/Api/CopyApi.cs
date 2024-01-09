using System.ComponentModel.DataAnnotations;
using Azure;
using Azure.Storage.Files.Shares.Models;
using BlobCopyTestApp.Clients;
using BlobCopyTestApp.Models;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using static BlobCopyTestApp.Api.BlobApi;

namespace BlobCopyTestApp.Api;

public static class CopyApi
{
    private const string BlobContainerName = "copytest";
    private const string FileShareName = "copytest";
    private const string BlobName = "test.txt";
    private const string CopiedBlobName = "test-from-{0}.txt";
    private const string StorageAccountKeySecretName = "{0}{1}StorageAccountKey";

    public static void RegisterCopyApi(this WebApplication app)
    {
        app.MapPost("/copy",
        [SwaggerOperation(Summary = "Copies blob to file share", Description = "Copies a blob from a storage account to a file share using the given locations (regions) e.g., from \"westeurope\" to \"swedencentral\".")]
        async ([FromQuery][Required] string sourceLocation, [FromQuery][Required] string destinationLocation) =>
        {
            CopyResult copyResult;

            try
            {
                copyResult = await CopyAsync(sourceLocation, destinationLocation, app.Logger);
            }
            catch (Exception e)
            {
                return Results.Problem(title: $"Failed to copy", detail: e.Message, statusCode: StatusCodes.Status500InternalServerError);
            }

            return Results.Ok(copyResult);
        })
        .WithTags("Copy")
        .Produces<CopyResult>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);

        app.MapPost("/copy/all",
        [SwaggerOperation(Summary = "Copies blobs to file shares", Description = "Copies a blob from a storage account to a file share using all the possible location combinations.")]
        async () =>
        {
            Location[] locations = { Location.PrimaryLocation, Location.SecondaryLocation };
            IList<CopyResult> copyResults = new List<CopyResult>();

            foreach (Location sourceLocation in locations)
            {
                foreach (Location destinationLocation in locations)
                {
                    try
                    {
                        copyResults.Add(await CopyAsync(sourceLocation, destinationLocation, app.Logger));
                    }
                    catch (Exception e)
                    {
#pragma warning disable CS8601 // Possible null reference assignment.
                        copyResults.Add(new CopyResult()
                        {
                            SourceLocation = LocationEnumToString(sourceLocation),
                            DestinationLocation = LocationEnumToString(destinationLocation),
                            CopyStatus = CopyStatus.Failed,
                            Message = e.Message
                        });
#pragma warning restore CS8601 // Possible null reference assignment.
                    }
                }
            }

            return Results.Ok(copyResults);
        })
        .WithTags("Copy")
        .Produces<IList<CopyResult>>(StatusCodes.Status200OK)
        .Produces(StatusCodes.Status500InternalServerError);
    }

    public static async Task<CopyResult> CopyAsync(Location sourceLocation, Location destinationLocation, ILogger logger)
    {
        string? from = LocationEnumToString(sourceLocation);
        string? to = LocationEnumToString(destinationLocation);

        if (string.IsNullOrEmpty(from) || string.IsNullOrEmpty(to))
        {
            throw new InvalidOperationException("Failed to resolve locations");
        }

        return await CopyAsync(from, to, logger);
    }

    public static async Task<CopyResult> CopyAsync(string from, string to, ILogger logger)
    {

        string? blobStorageAccountNamePrefix = Environment.GetEnvironmentVariable("BLOB_STORAGE_ACCOUNT_NAME_PREFIX");
        string? fileShareStorageAccountNamePrefix = Environment.GetEnvironmentVariable("FILE_SHARE_STORAGE_ACCOUNT_NAME_PREFIX");

        if (string.IsNullOrWhiteSpace(blobStorageAccountNamePrefix)
            || string.IsNullOrWhiteSpace(fileShareStorageAccountNamePrefix))
        {
            throw new InvalidOperationException("Missing environment values for storage account name prefixes");
        }

        string destinationFilePath = string.Format(CopiedBlobName, from);
        string fileShareStorageAccountKeySecretName = string.Format(StorageAccountKeySecretName, fileShareStorageAccountNamePrefix, to);
        string? fileShareStorageAccountKey;

        CopyResult copyResult = new()
        {
            SourceLocation = from,
            DestinationLocation = to
        };

        try
        {
            KeyVaultClient keyVaultClient = new();
            fileShareStorageAccountKey = await keyVaultClient.GetSecretAsync(fileShareStorageAccountKeySecretName);
        }
        catch (Exception e)
        {
            copyResult.Message = $"Failed to retrieve file share storage account key by secret name {fileShareStorageAccountKeySecretName}: {e.Message}";
            return copyResult;
        }

        string blobStorageAccountName = $"{blobStorageAccountNamePrefix}{from}";
        string fileShareStorageAccountName = $"{fileShareStorageAccountNamePrefix}{to}";
        ShareFileCopyInfo? shareFileCopyInfo = null;

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
        }
        catch (RequestFailedException e)
        {
            copyResult.StatusCode = e.Status;
            copyResult.Message = $"Failed to copy from {from} to {to}: {e.Message}";
            logger.LogError(copyResult.Message);
        }
        catch (Exception e)
        {
            copyResult.Message = $"Failed to copy from {from} to {to}: {e.Message}";
            logger.LogError(copyResult.Message);
        }

        copyResult.CopyStatus = (shareFileCopyInfo == null) ? CopyStatus.Failed : shareFileCopyInfo.CopyStatus;
        logger.LogInformation("Copy operation appears to have successful or successfully started");
        return copyResult;
    }
}
