#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build

ARG SEMVER_PREFIX=2.1.0
ARG DEPLOYMENT_ENVIRONMENT=dev
ARG COMMIT_SHA
ARG BUILD_CONFIGURATION=Debug

WORKDIR /src
COPY ["BlobCopyTestApp/BlobCopyTestApp.csproj", "BlobCopyTestApp/"]
RUN dotnet restore "./BlobCopyTestApp/./BlobCopyTestApp.csproj"
COPY . .
WORKDIR "/src/BlobCopyTestApp"
RUN dotnet build "./BlobCopyTestApp.csproj" --configuration $BUILD_CONFIGURATION --output /app/build /property:Version="${SEMVER_PREFIX}-${DEPLOYMENT_ENVIRONMENT}+${COMMIT_SHA}" /warnaserror

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./BlobCopyTestApp.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "BlobCopyTestApp.dll"]
