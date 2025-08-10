variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "europe-west1-b"
}

variable "db_version" {
  description = "The database version (MYSQL_8_0, POSTGRES_14, etc.)"
  type        = string
  default     = "POSTGRES_14"
}

variable "db_user" {
  description = "Database user name"
  type        = string
  default     = "webappuser"
}

variable "db_password" {
  description = "Database user password"
  type        = string
  sensitive   = true
}

variable "lb_domain" {
  description = "Domain for managed SSL certificate on load balancer"
  type        = string
  default     = "example.com"
}
