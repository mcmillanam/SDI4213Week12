locals {
  prefix = var.project_name
}

# ---------- Starter infrastructure: network + status portal ----------
resource "docker_network" "lab" {
  name = "${local.prefix}-network"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.30.6-alpine-slim"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "${local.prefix}-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.web_port
  }

  networks_advanced {
    name = docker_network.lab.name
  }

  volumes {
    host_path      = abspath("${path.module}/site")
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }

  restart = "unless-stopped"
}

# ---------- WEEK 12 TODO (Milestone 6) ----------
# Extend this configuration with:
# 1. docker_volume.postgres_data
resource "docker_volume" "postgres_data" {
  name = "${local.prefix}-postgres-data"
}
# 2. docker_image.postgres using postgres:18.6-alpine
resource "docker_image" "postgres" {
  name         = "postgres:18.6-alpine"
  keep_locally = true
}
# 3. docker_container.db attached to docker_network.lab
#    - POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD from variables
#    - mount docker_volume.postgres_data at /var/lib/postgresql/data
resource "docker_container" "db" {
  name  = "${local.prefix}-db"
  image = docker_image.postgres.image_id
  env = [
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}"
  ]
  networks_advanced {
    name = docker_network.lab.name
  }
  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql"
  }
  restart = "unless-stopped"
}
# 4. docker_image.adminer using adminer:5.5.1
resource "docker_image" "adminer" {
  name         = "adminer:5.5.1"
  keep_locally = true
}
# 5. docker_container.adminer attached to docker_network.lab
#    - publish internal port 8080 to var.adminer_port
#    - set ADMINER_DEFAULT_SERVER to the database container name
#
# See docs/resource_hints.md for field-level hints. Do not copy real secrets
# into any committed .tf file.
resource "docker_container" "adminer" {
  name  = "${local.prefix}-adminer"
  image = docker_image.adminer.image_id

  env = [
    "ADMINER_DEFAULT_SERVER=${docker_container.db.name}"
  ]
  ports {
    internal = 8080
    external = var.adminer_port
  }
  networks_advanced {
    name = docker_network.lab.name
  }
  restart = "unless-stopped"
}
