using Microsoft.EntityFrameworkCore;
using SampleApi;
using SampleApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Application Insights — connection string comes from Key Vault reference in app settings:
// ApplicationInsights__ConnectionString = @Microsoft.KeyVault(VaultName=kv-my-api-dev;SecretName=appInsightsConnectionString)
builder.Services.AddApplicationInsightsTelemetry();

// SQL — connection string comes from Key Vault reference:
// ConnectionStrings__Default = @Microsoft.KeyVault(VaultName=kv-my-api-dev;SecretName=sqlConnectionString)
// The app reads this via IConfiguration — it never sees the raw connection string.
builder.Services.AddDbContext<SampleDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

// Health endpoint — consumed by App Service health check and pipeline smoke tests.
// Returns the deployment environment so tests can verify the right env was deployed.
app.MapGet("/health", (IWebHostEnvironment env) => new HealthResponse(
    Status: "Healthy",
    Environment: env.EnvironmentName,
    Version: typeof(Program).Assembly.GetName().Version?.ToString() ?? "0.0.0"
))
.WithName("GetHealth")
.Produces<HealthResponse>();

// Sample data endpoint demonstrating SQL connectivity via managed identity
app.MapGet("/api/items", async (SampleDbContext db) =>
    await db.Items.OrderBy(i => i.Id).ToListAsync())
.WithName("GetItems")
.Produces<List<Item>>();

app.Run();

// Partial class required for WebApplicationFactory in integration tests
public partial class Program { }
