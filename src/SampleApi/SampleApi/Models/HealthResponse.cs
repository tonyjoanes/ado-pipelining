namespace SampleApi.Models;

public record HealthResponse(
    string Status,
    string Environment,
    string Version
);
