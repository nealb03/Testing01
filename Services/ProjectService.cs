using System.Collections.Generic;
using Project1.Models;

namespace Project1.Services
{
    public static class ProjectService
    {
        // Returns a sample list of projects
        public static List<Project> GetAll()
        {
            return new List<Project>
            {
                new Project { Id = 1, Name = "Project One", Description = "First project" },
                new Project { Id = 2, Name = "Project Two", Description = "Second project" }
            };
        }
    }
}