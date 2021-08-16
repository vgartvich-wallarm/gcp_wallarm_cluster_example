resource "google_compute_network" "vpc" {
  name    = "${var.name_prefix}-vpc"
  project = var.project
  auto_create_subnetworks = "false"
  routing_mode = "REGIONAL"
}

resource "google_compute_router" "vpc_router" {
  name = "${var.name_prefix}-router"
  project = var.project
  region  = var.region
  network = google_compute_network.vpc.self_link
}

data "google_compute_zones" "available" {
}

resource "google_compute_subnetwork" "public" {
  count = var.az_count
  name = "${var.name_prefix}-subnet-${data.google_compute_zones.available.names[count.index]}"

  project = var.project
  region  = var.region
  network = google_compute_network.vpc.self_link

  private_ip_google_access = true
  ip_cidr_range            = cidrsubnet(var.vpc_cidr_block, 8, count.index)  
}

resource "google_compute_router_nat" "vpc_nat" {
  name = "${var.name_prefix}-nat"

  project = var.project
  region  = var.region
  router  = google_compute_router.vpc_router.name

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

}

resource "google_compute_firewall" "firewall" {
  name = "${var.name_prefix}-firewall"

  project = var.project
  network = google_compute_network.vpc.self_link

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  priority = "1000"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = [ "22", "80", "443"]
  }

}
