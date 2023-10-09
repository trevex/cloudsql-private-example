terraform {
  backend "gcs" {
    bucket = "nvoss-cloudsql-paris-tf-state"
    prefix = "terraform/1-services"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

# Enable required APIs

resource "google_project_service" "services" {
  for_each = toset([
    "servicenetworking.googleapis.com",
    "redis.googleapis.com"
  ])
  project = var.project
  service = each.value
}

# Network to peer with for our private CloudSQL
data "google_compute_network" "peering_network" {
  name    = var.peering_network_name
  project = var.project
}

# Let's reserve IPs for peering (for private access to GCP services)
resource "google_compute_global_address" "services_private_ips" {
  name          = "services-private-ips"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.peering_network.id
}

# Let create a peering connection to the service network
resource "google_service_networking_connection" "services_private" {
  network                 = data.google_compute_network.peering_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.services_private_ips.name]

  depends_on = [google_project_service.services]
}

# Let's make sure we export and import routes to ensure connectivity
resource "google_compute_network_peering_routes_config" "services_private" {
  peering              = google_service_networking_connection.services_private.peering
  network              = data.google_compute_network.peering_network.name
  import_custom_routes = true
  export_custom_routes = true
}


# A private CloudSQL
resource "google_sql_database_instance" "cloudsql_private" {
  name             = "cloudsql-private"
  region           = var.region
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = "false"
      private_network = data.google_compute_network.peering_network.id
    }
  }

  depends_on          = [google_service_networking_connection.services_private]
  deletion_protection = false
}

# A private Redis


resource "google_redis_instance" "redis_private" {
  name           = "redis-private"
  tier           = "BASIC"
  redis_version  = "REDIS_4_0"
  display_name   = "Redis Private"
  memory_size_gb = 1

  region = var.region

  authorized_network = data.google_compute_network.peering_network.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"


  depends_on = [google_service_networking_connection.services_private]
}
