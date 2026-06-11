using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SampleApi;
using SampleApi.Models;

namespace SampleApi.Tests;

// WebApplicationFactory spins up the real application in-memory.
// SQL is replaced with an in-memory provider so no database is needed.
public class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace SQL Server with in-memory provider for unit tests
                var descriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(DbContextOptions<SampleDbContext>));
                if (descriptor != null) services.Remove(descriptor);

                services.AddDbContext<SampleDbContext>(options =>
                    options.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetHealth_ReturnsOk()
    {
        var response = await _client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetHealth_ReturnsHealthyStatus()
    {
        var health = await _client.GetFromJsonAsync<HealthResponse>("/health");

        Assert.NotNull(health);
        Assert.Equal("Healthy", health.Status);
    }

    [Fact]
    public async Task GetHealth_ReturnsVersionString()
    {
        var health = await _client.GetFromJsonAsync<HealthResponse>("/health");

        Assert.NotNull(health);
        Assert.False(string.IsNullOrEmpty(health.Version));
    }

    [Fact]
    public async Task GetItems_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/items");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetItems_ReturnsEmptyListWhenNoData()
    {
        var items = await _client.GetFromJsonAsync<List<Item>>("/api/items");

        Assert.NotNull(items);
        Assert.Empty(items);
    }
}
