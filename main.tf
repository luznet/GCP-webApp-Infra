# Specify required providers
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.3.0"
}
# Main Terraform configuration for GCP WebApp Infrastructure

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google" {
  alias  = "impersonate"
  project = var.project_id
  region  = var.region
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "7.2.0"

  project_id   = var.project_id
  network_name = "webapp-network"
  subnets = [
    {
      subnet_name   = "webapp-subnet"
      subnet_ip     = "10.10.0.0/24"
      subnet_region = var.region
    }
  ]
  secondary_ranges = {}
}

# Firewall rules: allow HTTP/HTTPS to webservers, deny all else by default
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = module.network.network_self_link
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags = ["webserver"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = module.network.network_self_link
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  target_tags = ["webserver"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "deny_all_egress" {
  name    = "deny-all-egress"
  network = module.network.network_self_link
  deny {
    protocol = "all"
  }
  direction = "EGRESS"
  priority  = 65534
  destination_ranges = ["0.0.0.0/0"]
}


# Cloud SQL instance (native resource)
resource "google_sql_database_instance" "webapp" {
  name             = "webapp-db"
  project          = var.project_id
  region           = var.region
  database_version = var.db_version
  settings {
    tier              = "db-custom-1-3840"
    availability_type = "REGIONAL"
    ip_configuration {
      ipv4_enabled    = false
      private_network = module.network.network_self_link
    }
    backup_configuration {
      enabled                        = var.backup_enabled
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
    }
  }
  deletion_protection = false
}

# Cloud SQL user (native resource)
resource "google_sql_user" "webapp" {
  name     = var.db_user
  instance = google_sql_database_instance.webapp.name
  password = google_secret_manager_secret_version.db_password.secret_data
  host     = "%"
}

# Cloud SQL database (native resource)
resource "google_sql_database" "webapp" {
  name     = "webappdb"
  instance = google_sql_database_instance.webapp.name
  charset  = "UTF8"
  collation = "en_US.UTF8"
}


# Secret Manager for DB password
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  replication {
    # automatic = true # Deprecated, removed for compatibility
  }
  labels = {
    owner        = var.owner
    project_name = var.project_name
    environment  = var.environment
    used_by      = var.used_by
    owner_email  = var.owner_email
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

module "webserver_group" {
  source  = "terraform-google-modules/vm/google//modules/mig"
  version = "7.9.0"

  project_id = var.project_id
  region     = var.region
  instance_template = module.webserver_template.self_link
  target_size = 2
  named_ports = [{ name = "http", port = 80 }]
}

module "webserver_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "7.9.0"

  project_id = var.project_id
  region     = var.region
  name_prefix = "webserver-template"
  machine_type = "e2-medium"
  service_account = {
    email  = google_service_account.webapp_sa.email
    scopes = ["cloud-platform"]
  }
  tags = ["webserver"]
  metadata = {
    startup-script = file("startup.sh")
    enable-oslogin = "TRUE"
  }
  source_image_family = "debian-11"
  source_image_project = "debian-cloud"
  network = module.network.network_self_link
  subnetwork = module.network.subnets_self_links[0]
}

resource "google_service_account" "webapp_sa" {
  account_id   = "webapp-sa"
  display_name = "WebApp Service Account"
  project      = var.project_id
}

# Grant least privilege roles to service account
resource "google_project_iam_member" "webapp_sa_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.webapp_sa.email}"
}

module "lb" {
  source  = "terraform-google-modules/lb-http/google"
  version = "9.0.0"

  project = var.project_id
  name    = "webapp-lb"
  backends = {
    default = {
      group = module.webserver_group.instance_group
      description = "Web server group"
      enable_cdn = false
      health_check = {
        request_path = "/"
        port         = 80
      }
    }
  }
  ssl = true
  managed_ssl_certificate_domains = [var.lb_domain]
  http_forward = true
  https_redirect = true
  create_address = true
}

# Cloud SQL Monitoring Alert: High CPU Utilization
resource "google_monitoring_alert_policy" "sql_high_cpu" {
  display_name = "Cloud SQL High CPU Utilization"
  combiner     = "OR"
  conditions {
    display_name = "Cloud SQL CPU > 80%"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\" resource.label.\"database_id\"=\"${google_sql_database_instance.webapp.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      trigger {
        count = 1
      }
    }
  }
  notification_channels = [] # Add channel IDs here
  enabled = true
}

# Cloud SQL Monitoring Alert: Storage Utilization
resource "google_monitoring_alert_policy" "sql_high_storage" {
  display_name = "Cloud SQL High Storage Utilization"
  combiner     = "OR"
  conditions {
    display_name = "Cloud SQL Storage > 80%"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\" resource.label.\"database_id\"=\"${google_sql_database_instance.webapp.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      trigger {
        count = 1
      }
    }
  }
  notification_channels = [] # Add channel IDs here
  enabled = true
}
