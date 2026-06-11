using Microsoft.EntityFrameworkCore;
using SampleApi.Models;

namespace SampleApi;

public class SampleDbContext(DbContextOptions<SampleDbContext> options) : DbContext(options)
{
    public DbSet<Item> Items => Set<Item>();
}
