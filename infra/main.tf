terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  required_version = ">= 1.4"
}

provider "docker" {}

# ------------ Variables you may tweak ------------
variable "project_root" {
  description = "Path to your local project root that contains frontend and backend code"
  type        = string
  default     = "C:/nealb03/Testing01/Testing01"
}

variable "frontend_dir" {
  description = "Relative path from project_root to frontend app (with Dockerfile)"
  type        = string
  default     = "frontend"
}

variable "backend_dir" {
  description = "Relative path from project_root to backend app (with Dockerfile)"
  type        = string
  default     = "backend"
}

variable "frontend_host_port" {
  type    = number
  default = 3000
}

variable "backend_host_port" {
  type    = number
  default = 8080
}

variable "db_user" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  default   = "apppassword"
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "appdb"
}

# ------------ Network and volumes ------------
resource "docker_network" "app" {
  name = "app_net"
}

resource "docker_volume" "pg_data" {
  name = "pg_data_vol"
}

# ------------ Seed SQL for test user ------------
locals {
  init_sql = <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL
    );
    -- bcrypt hash for "password" ($2b$10$...)
    INSERT INTO users (username, password_hash)
    VALUES ('testuser1', '$2b$10$N9qo8uLOickgx2ZMRZo5i.ez6WfQWf1iY4zYx2QVX8W2u0YQnXQW2')
    ON CONFLICT (username) DO NOTHING;
  SQL
}

resource "local_file" "init_sql" {
  filename = "${path.module}/db-init/init.sql"
  content  = local.init_sql
}

# ------------ Database container (PostgreSQL) ------------
resource "docker_image" "postgres" {
  name         = "postgres:16"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "app_db"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=${var.db_name}",
  ]

  mounts {
    target = "/var/lib/postgresql/data"
    type   = "volume"
    source = docker_volume.pg_data.name
  }

  # Use absolute, normalized path for Windows bind mount
  mounts {
    target = "/docker-entrypoint-initdb.d"
    type   = "bind"
    source = replace(abspath("${path.module}/db-init"), "\\", "/")
  }

  networks_advanced {
    name = docker_network.app.name
  }

  # Ensure init.sql is written before the DB starts
  depends_on = [local_file.init_sql]
}

# ------------ Backend image + container ------------
resource "docker_image" "backend" {
  name = "local/backend:latest"

  build {
    # Normalize to absolute POSIX-style path for Windows
    context    = replace(abspath("${var.project_root}/${var.backend_dir}"), "\\", "/")
    dockerfile = "dockerfile" # lowercase to match your file name
  }

  keep_locally = true
}

resource "docker_container" "backend" {
  name  = "app_backend"
  image = docker_image.backend.image_id

  env = [
    "DB_HOST=app_db",
    "DB_PORT=5432",
    "DB_USER=${var.db_user}",
    "DB_PASSWORD=${var.db_password}",
    "DB_NAME=${var.db_name}",
    "DATABASE_URL=postgres://${var.db_user}:${var.db_password}@app_db:5432/${var.db_name}",
    "CORS_ORIGIN=http://localhost:${var.frontend_host_port}",
  ]

  ports {
    internal = 8080
    external = var.backend_host_port
  }

  networks_advanced {
    name = docker_network.app.name
  }

  depends_on = [docker_container.db]
}

# ------------ Frontend image + container ------------
resource "docker_image" "frontend" {
  name = "local/frontend:latest"

  build {
    # Normalize to absolute POSIX-style path for Windows
    context    = replace(abspath("${var.project_root}/${var.frontend_dir}"), "\\", "/")
    dockerfile = "dockerfile" # lowercase to match your file name
    build_args = {
      REACT_APP_API_URL = "http://localhost:${var.backend_host_port}"
      VITE_API_URL      = "http://localhost:${var.backend_host_port}"
    }
  }

  keep_locally = true
}

resource "docker_container" "frontend" {
  name  = "app_frontend"
  image = docker_image.frontend.image_id

  ports {
    internal = 3000
    external = var.frontend_host_port
  }

  networks_advanced {
    name = docker_network.app.name
  }

  depends_on = [docker_container.backend]
}