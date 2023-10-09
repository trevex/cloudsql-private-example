output "redis_private_ip" {
  value = google_redis_instance.redis_private.host
}

output "postgres_private_ip" {
  value = google_sql_database_instance.cloudsql_private.private_ip_address
}

