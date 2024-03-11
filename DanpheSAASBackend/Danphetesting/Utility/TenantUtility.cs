using Danphetesting.Context;
using Danphetesting.Models;
using Microsoft.Data.SqlClient.Server;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Metadata.Ecma335;

namespace Danphetesting.Utility
{
    public class TenantUtility
    {
        private readonly TenantDbContext _context;
        public TenantUtility(TenantDbContext context)
        {
            _context = context;
        }
        public bool IsCorporateEmail(string email)
        {
            string domain = GetDomainFromEmail(email);
            var domainexist = _context.EmailDomains.FirstOrDefault(i => i.EmailProviders == domain);

            if (domainexist != null)
            {
                return false;
            }
            return true;
        }

        public bool DomainAlreadyExist(string email)
        {
            string domain = GetDomainFromEmail(email);
            List<string> domainsFromDatabase = _context.Tenants
                           .Select(t => GetDomainFromEmail(t.Email))
                           .Distinct()
                           .ToList();
            List<string> allowDomains= new List<string> { "questpond.com", "imark.com" };
            if (domainsFromDatabase.Contains(domain) && !allowDomains.Contains(domain))
            { 
                return false;
            }
            return true;
        }
        static string GetDomainFromEmail(string email)
        {
            // Find the position of the "@" symbol
            int atIndex = email.IndexOf('@');

            string domain = email.Substring(atIndex + 1);

            return domain;
        }

        public string GenerateTenanatId(string HospitalShortName)
        {
            string tenantId;
            int MaxId;
            try
            {

                MaxId = _context.Tenants.Max<Tenant>(i => i.Id);

            }
            catch (Exception ex)
            {
                MaxId = 0;
            }

            if (MaxId == 0)
            {
                tenantId = $"{HospitalShortName}{1000}";
            }
            else
            {
                tenantId = $"{HospitalShortName}{MaxId + 1}";
            }
            return tenantId;
        }
    }

    
}
