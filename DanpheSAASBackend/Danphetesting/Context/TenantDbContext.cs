using Danphetesting.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Danphetesting.Context
{
    public class TenantDbContext : DbContext
    {


        public TenantDbContext(DbContextOptions<TenantDbContext> options) : base(options)
        {
        }


        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Tenant>().ToTable("Tenants");
            modelBuilder.Entity<Tenant>().HasKey(a => a.Id);

            modelBuilder.Entity<EmailDomain>().ToTable("EmailProviders");
            modelBuilder.Entity<EmailDomain>().HasKey(e => e.id);

            modelBuilder.Entity<Configuration>().ToTable("Configuration");
            modelBuilder.Entity<Configuration>().HasKey(e => e.ParameterId);



        }
        public DbSet<Tenant> Tenants { get; set; }
        public DbSet<EmailDomain> EmailDomains { get; set; }
        public DbSet<Configuration> configurations { get; set; }
        


    }
}
