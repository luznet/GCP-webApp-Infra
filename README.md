# GCP Web Application Infrastructure (Terraform)

This repository contains Terraform code to provision a secure, scalable, and highly available web application infrastructure on Google Cloud Platform (GCP).

## Features
- **VPC Network**: Custom network and subnet for isolation
- **Firewall**: Only HTTP/HTTPS allowed to web servers, all other traffic denied
- **Web Server**: Managed Instance Group (Nginx/Apache) with autoscaling and load balancing
- **Cloud SQL**: Highly available PostgreSQL/MySQL instance with private IP
- **Cloud Storage**: GCS bucket for static assets or file uploads
- **Secret Manager**: Secure storage for database credentials
- **Service Accounts & IAM**: Least-privilege access for automation and security


## Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.3.0
- Google Cloud account and project
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- Service account with sufficient permissions (compute, sql, storage, secretmanager)

## Google Cloud Authentication

Before running Terraform, authenticate with Google Cloud:

1. **Install the Google Cloud SDK (gcloud) if not already installed:**
	```# Download the latest Google Cloud SDK
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-456.0.0-linux-x86_64.tar.gz

# Extract to /opt/gcloud (requires sudo)
sudo mkdir -p /opt/gcloud
sudo tar -C /opt/gcloud -xzf google-cloud-sdk-456.0.0-linux-x86_64.tar.gz

# (Optional) Remove the downloaded archive
rm google-cloud-sdk-456.0.0-linux-x86_64.tar.gz

# Initialize the SDK
/opt/gcloud/google-cloud-sdk/install.sh

# Add gcloud to your PATH (add this to your ~/.bashrc or ~/.profile for persistence)
export PATH="/opt/gcloud/google-cloud-sdk/bin:$PATH"
	```

2. **Login to your Google account:**
	```bash
	gcloud auth login
	```

3. **Set your active project (replace with your project ID):**
	```bash
	gcloud config set project YOUR_PROJECT_ID
	```

4. **(Optional) Set default region/zone:**
	```bash
	gcloud config set compute/region YOUR_REGION
	gcloud config set compute/zone YOUR_ZONE
	```

Terraform will automatically use the credentials from your gcloud session.

If you want to use a service account for automation, see the [official docs](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) for details.

## Usage
1. **Clone the repository**
	```bash
	git clone https://github.com/luznet/GCP-webApp-Infra.git
	cd GCP-webApp-Infra
	```
2. **Create a `terraform.tfvars` file** with your configuration:
	```hcl
	project_id   = "your-gcp-project-id"
	db_password  = "your-db-password" # Or use a secure method
	lb_domain    = "your-domain.com"  # For managed SSL
	```
3. **Initialize Terraform**
	```bash
	terraform init
	```
4. **Review the plan**
	```bash
	terraform plan
	```
5. **Apply the configuration**
	```bash
	terraform apply
	```

## Outputs
- VPC network name
- GCS bucket name
- Cloud SQL instance connection name
- Managed instance group info
- Load balancer IP

## Security & Best Practices
- No secrets or state files are tracked in git
- All sensitive variables should be managed via Secret Manager or tfvars (never hardcoded)
- Use a remote backend for state in production
- Review IAM permissions and firewall rules for least privilege

## Clean Up

To destroy all resources for a specific environment:
```bash
# For DEV
echo "Destroying DEV..."
terraform destroy -var-file=dev.tfvars

# For PROD
echo "Destroying PROD..."
terraform destroy -var-file=prod.tfvars

```

## License
MIT
# GCP-webApp-Infra
GCP web application Infrastructure setup
