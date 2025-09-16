using Microsoft.AspNetCore.Mvc;
using Project1.Models;
using Project1.Services;
using System.Collections.Generic;

namespace Project1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class Project1Controller : ControllerBase
    {
        [HttpGet]
        public ActionResult<List<Project>> GetAll()
        {
            var projects = ProjectService.GetAll();
            return Ok(projects);
        }
    }
}