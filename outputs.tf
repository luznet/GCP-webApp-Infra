output "network_name" {
  value = module.network.network_name
}

output "gcs_bucket" {
  value = module.gcs.name
}

output "sql_instance_connection_name" {
  value = module.sql.connection_name
}

output "webserver_group" {
  value = module.webserver_group.instance_group
}

output "load_balancer_ip" {
  value = module.lb.external_ip
}
