terraform {
  backend "gcs" {
    bucket = "nvoss-sql-private-tf-state"
    prefix = "terraform/cluster-0"
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
    "cloudresourcemanager.googleapis.com", # required by terraform
    "compute.googleapis.com",
    "container.googleapis.com",
  ])
  project = var.project
  service = each.value
}

# The underlying network mainly for the cluster

module "network" {
  source = "../modules//network"

  name = "mynetwork"
  subnetworks = [{
    name_affix    = "main" # full name will be `${name}-${name_affix}-${region}`
    ip_cidr_range = "10.0.0.0/20"
    region        = var.region
    secondary_ip_range = [{ # Use larger ranges in production!
      range_name    = "pods"
      ip_cidr_range = "10.0.32.0/19"
      }, {
      range_name    = "services"
      ip_cidr_range = "10.0.16.0/20"
    }]
  }]

  depends_on = [google_project_service.services]
}


# Create GKE Autopilot cluster

module "cluster" {
  source = "../modules//cluster"

  name                   = "mycluster"
  project                = var.project
  region                 = var.region
  network_id             = module.network.id
  subnetwork_id          = module.network.subnetworks["mynetwork-main-${var.region}"].id
  master_ipv4_cidr_block = "172.16.0.0/28"

  depends_on = [module.network]
}
