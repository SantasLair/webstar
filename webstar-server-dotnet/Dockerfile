# Use the official .NET 9 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies (for better caching)
COPY WebStarServer.csproj .
RUN dotnet restore WebStarServer.csproj

# Copy everything else and build
COPY . .
RUN dotnet build WebStarServer.csproj -c Release -o /app/build

# Publish the application
RUN dotnet publish WebStarServer.csproj -c Release -o /app/publish /p:UseAppHost=false

# Use the official .NET 9 runtime image for running
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Create a non-root user for security
RUN groupadd -r webstar && useradd -r -g webstar webstar

# Copy the published application
COPY --from=build /app/publish .

# Change ownership to the non-root user
RUN chown -R webstar:webstar /app
USER webstar

# Expose the port the app runs on
EXPOSE 5090

# Set environment variables for production
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:5090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5090/health || exit 1

# Start the application
ENTRYPOINT ["dotnet", "WebStarServer.dll"]
