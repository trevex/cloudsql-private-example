output "id" {
  value = google_compute_network.network.id
}

output "name" {
  value = google_compute_network.network.name
}

output "subnetworks" {
  value = google_compute_subnetwork.subnetworks
}
