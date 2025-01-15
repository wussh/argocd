# Terraform provider block for Google Cloud
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region1
}

# Input Variables Section

# GCP Project
variable "gcp_project" {
  description = "Project in which GCP Resources to be created"
  type        = string
  default     = "wushonline"
}

# GCP Region
variable "gcp_region1" {
  description = "Region in which GCP Resources to be created"
  type        = string
  default     = "asia-southeast2"
}

# GCP Compute Engine Machine Type
variable "machine_type" {
  description = "Compute Engine Machine Type"
  type        = string
  default     = "e2-medium"
}

# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
  default     = "dev"
}

# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type        = string
  default     = "wush"
}

# Locals Section for Reusability and Consistency
locals {
  owners      = var.business_divsion
  environment = var.environment
  name        = "${var.business_divsion}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
}

# VPC Network Configuration
resource "google_compute_network" "myvpc" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
}

# Subnetwork Configuration
resource "google_compute_subnetwork" "mysubnet" {
  name                     = "${local.name}-${var.gcp_region1}-subnet"
  region                   = var.gcp_region1
  ip_cidr_range            = "10.128.0.0/20"
  network                  = google_compute_network.myvpc.id 
  private_ip_google_access = true
}

# Firewall Rule for SSH Access
resource "google_compute_firewall" "fw_ssh" {
  name          = "${local.name}-fwrule-allow-ssh22"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.myvpc.id 
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-tag"]
}

# Resource: GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name                     = "${local.name}-gke-cluster"
  location                 = var.gcp_region1
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.myvpc.self_link
  subnetwork               = google_compute_subnetwork.mysubnet.self_link
  deletion_protection      = false
}

# Resource: GKE Node Pool
resource "google_container_node_pool" "nodepool_1" {
  name       = "${local.name}-node-pool-1"
  location   = var.gcp_region1
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 1

  autoscaling {
    min_node_count = 5
    max_node_count = 10
    location_policy = "BALANCED"
  }

  node_config {
    spot          = true
    machine_type  = var.machine_type
    disk_type     = "pd-standard"
    disk_size_gb  = 20
    service_account = "794060031908-compute@developer.gserviceaccount.com"
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = ["ssh-tag"]
  }
}

# Terraform Outputs Section

# Output: GKE Cluster Name
output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke_cluster.name
}

# Output: GKE Cluster Location
output "gke_cluster_location" {
  description = "GKE Cluster location"
  value       = google_container_cluster.gke_cluster.location
}

# Output: GKE Cluster Endpoint
output "gke_cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = google_container_cluster.gke_cluster.endpoint
}

# Output: GKE Cluster Master Version
output "gke_cluster_master_version" {
  description = "GKE Cluster master version"
  value       = google_container_cluster.gke_cluster.master_version
}
