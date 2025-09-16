namespace Project1.Models
{
    public class Project
    {
        public int Id { get; set; }

        // To avoid CS8618 warning, initialize to empty string or make nullable
        public string Name { get; set; } = string.Empty;

        public string Description { get; set; } = string.Empty;
    }
}