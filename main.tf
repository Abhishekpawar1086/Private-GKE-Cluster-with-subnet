provider "google" {
  project = "your-project-id"
  region  = "us-central1"
}

# Create a VPC network
resource "google_compute_network" "vpc" {
  name                    = "gke-private-vpc"
  auto_create_subnetworks = false
}

# Create 2 subnets (for nodes and pods/services)
resource "google_compute_subnetwork" "subnet1" {
  name          = "gke-subnet-1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.1.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.2.0.0/20"
  }
}

resource "google_compute_subnetwork" "subnet2" {
  name          = "gke-subnet-2"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.3.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.4.0.0/20"
  }
}

# Create a private GKE cluster
resource "google_container_cluster" "private_gke" {
  name               = "private-gke-cluster"
  location           = "us-central1-a"
  initial_node_count = 1

  # Private cluster settings
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true  # Restrict API access to VPC
    master_ipv4_cidr_block  = "172.16.0.0/28"  # Master CIDR (must not overlap with subnets)
  }

  # Network configuration
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet1.name  # Primary subnet

  # IP ranges for pods/services (required for private clusters)
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  # Node pool configuration
  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Disable public endpoint (optional)
  master_authorized_networks_config {
    cidr_blocks = []  # Empty = no external access to master
  }
}
