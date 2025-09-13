# Use the official .NET 9 SDK image (includes both SDK and runtime)
FROM mcr.microsoft.com/dotnet/sdk:9.0
WORKDIR /app

# Copy the application files
COPY . .

# Remove launch settings that override URLs in production
RUN rm -f Properties/launchSettings.json

# Restore dependencies and build
RUN dotnet restore
RUN dotnet build -c Release

# Expose the port the app runs on
EXPOSE 5090

# Set environment variables
ENV ASPNETCORE_ENVIRONMENT=Development
ENV ASPNETCORE_URLS=http://0.0.0.0:5090

# Start the application
ENTRYPOINT ["dotnet", "run"]
