data "google_compute_image" "debian_image" {
  family  = "debian-9"
  project = "debian-cloud"
}

data "google_compute_zones" "available" {
}

resource "google_compute_instance_template" "wordpress" {
  name_prefix  = var.name_prefix
  machine_type = "f1-micro"
  region       = var.region

  disk {
    source_image = data.google_compute_image.debian_image.self_link
  }

  network_interface {
    network = var.vpc_self_link
    subnetwork = "${var.name_prefix}-subnet-${data.google_compute_zones.available.names[0]}"
  }

  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq nginx; sudo service nginx restart"

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "wordpress" {
  name                = "${var.name_prefix}-wordpress-compute-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    request_path = "/"
    port         = "80"
  }
}

locals {
  distribution_policy_zones = [
      for i in range(var.az_count) : data.google_compute_zones.available.names[i]
    ]
  }


resource "google_compute_region_instance_group_manager" "wordpress" {
  name = "${var.name_prefix}-wordpress"

  base_instance_name         = "wordpress"
  region                     = var.region
  distribution_policy_zones  = local.distribution_policy_zones
  target_size                = var.az_count

  version {
    instance_template = google_compute_instance_template.wordpress.id
  }

  named_port {
    name = "http"
    port = "80"
  }

  named_port {
    name = "https"
    port = "443"
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.wordpress.id
    initial_delay_sec = 300
  }
}


resource "google_compute_http_health_check" "wordpress" {
  name         = "${var.name_prefix}-wordpress-health-check"
  request_path = "/"
}

resource "google_compute_backend_service" "wordpress" {
  name      = "${var.name_prefix}-wordpress-backend-service"
  port_name = "http"
  protocol  = "HTTP"
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_instance_group_manager.wordpress.instance_group
  }

  health_checks = [
    google_compute_http_health_check.wordpress.id,
  ]
}

resource "google_compute_url_map" "wordpress" {
  name            = "${var.name_prefix}-wordpress-url-map"
  default_service = google_compute_backend_service.wordpress.self_link
}

resource "google_compute_target_http_proxy" "wordpress" {
  name    = "${var.name_prefix}-wordpress-http-proxy"
  url_map = google_compute_url_map.wordpress.self_link
}

resource "google_compute_global_forwarding_rule" "wordpress" {
  name   =  "${var.name_prefix}-wordpress-forwarding-rule"
  port_range            = "80"
  target     = google_compute_target_http_proxy.wordpress.self_link
}

