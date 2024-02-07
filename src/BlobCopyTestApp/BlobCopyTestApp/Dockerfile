FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build

ARG SEMVER_PREFIX=0.2.2
ARG DEPLOYMENT_ENVIRONMENT=dev
ARG COMMIT_SHA
ARG BUILD_CONFIGURATION=Debug

WORKDIR /src
COPY ./src/BlobCopyTestApp ./
RUN dotnet restore "./BlobCopyTestApp/BlobCopyTestApp.csproj"
WORKDIR "/src/BlobCopyTestApp"
#RUN dotnet build "./BlobCopyTestApp.csproj" --configuration $BUILD_CONFIGURATION --output /app/build /property:Version="${SEMVER_PREFIX}-${DEPLOYMENT_ENVIRONMENT}+${COMMIT_SHA}" /warnaserror
RUN dotnet publish "./BlobCopyTestApp.csproj" --configuration $BUILD_CONFIGURATION --output /app/publish /property:UseAppHost=false /property:Version="${SEMVER_PREFIX}-${DEPLOYMENT_ENVIRONMENT}+${COMMIT_SHA}" /warnaserror

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "BlobCopyTestApp.dll"]
