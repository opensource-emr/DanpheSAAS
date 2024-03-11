using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace Danphetesting.Models
{
    public class Tenant
    {

        public int Id { get; set; }
        public string HospitalName { get; set; }
        public string HospitalShortName { get; set; }
        public string Email { get; set; }
        public string ContactNumber { get; set; }
        public string TenantId { get; set; }
        public Boolean IsPaid { get; set; }
        public string WebUrl { get;set; }
        public DateTime CreatedOn { get; set; }
    }
}
