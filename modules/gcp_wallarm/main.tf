data "google_compute_image" "wallarm_image" {
  project = "wallarm-node-195710"
  name    = var.wallarm_image
}

data "google_compute_zones" "available" {
}

resource "google_compute_instance_template" "wallarm" {
  name_prefix  = var.name_prefix
  machine_type = "f1-micro"
  region       = var.region

  disk {
    source_image = data.google_compute_image.wallarm_image.self_link
  }

  network_interface {
    network    = var.vpc_self_link
    subnetwork = "${var.name_prefix}-subnet-${data.google_compute_zones.available.names[0]}"
  }

  # image support required for user-data https://cloud.google.com/container-optimized-os/docs/how-to/create-configure-instance
  # shortcut for demo purposes

  metadata_startup_script = <<-EOF

 cat << DEFAULT > /etc/nginx/sites-available/default
     server {
       listen 80 default_server;
       server_name _;
       wallarm_mode monitoring;
       # wallarm_instance 1;
       wallarm_enable_libdetection on;
       proxy_request_buffering on;
       location /healthcheck {
         return 200;
       }
       location / {
         # setting the address for request forwarding
         proxy_pass http://${var.origin_ip};
         proxy_set_header Host \$host;
         proxy_set_header X-Real-IP \$remote_addr;
         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
         set_real_ip_from 10.0.0.0/8;
         real_ip_header X-Forwarded-For;
       }
     }
DEFAULT

    /usr/share/wallarm-common/addnode --force  -u ${var.wallarm_deploy_username} -p '${var.wallarm_deploy_password}' -H ${var.wallarm_api_domain} --batch
    systemctl restart nginx
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "wallarm" {
  name                = "${var.name_prefix}-wallarm-compute-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  tcp_health_check {
    port = "80"
  }
}

locals {
  distribution_policy_zones = [
    for i in range(var.az_count) : data.google_compute_zones.available.names[i]
  ]
}

resource "google_compute_region_instance_group_manager" "wallarm" {
  name = "${var.name_prefix}-wallarm"

  base_instance_name        = "wallarm"
  region                    = var.region
  distribution_policy_zones = local.distribution_policy_zones
  target_size               = var.az_count

  version {
    instance_template = google_compute_instance_template.wallarm.id
  }

  named_port {
    name = "http"
    port = "80"
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.wallarm.id
    initial_delay_sec = 300
  }
}


resource "google_compute_region_health_check" "wallarm_http" {
  name = "${var.name_prefix}-wallarm-http-region-health-check"

  timeout_sec        = 3
  check_interval_sec = 5

  http_health_check {
    port = "80"
    request_path = "/healthcheck"
  }
}


resource "google_compute_region_autoscaler" "wallarm" {
  name   = "${var.name_prefix}-wallarm-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.wallarm.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 120
    cpu_utilization {
      target = 0.4
    }
  }
}

resource "google_compute_region_backend_service" "wallarm_http" {
  name                  = "${var.name_prefix}-wallarm-backend-http-service"
  port_name             = "http"
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  #session_affinity      = "HTTP_COOKIE"

  backend {
    group = google_compute_region_instance_group_manager.wallarm.instance_group
  }

  health_checks = [
    google_compute_region_health_check.wallarm_http.id
  ]
}

resource "google_compute_address" "wallarm_nlb" {
  name         = "${var.name_prefix}-wallarm-nlb-ip"
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_forwarding_rule" "wallarm_http" {
  name            = "${var.name_prefix}-wallarm-http-forwarding-rule"
  region          = var.region
  ip_address      = google_compute_address.wallarm_nlb.self_link
  ip_protocol     = "TCP"
  port_range      = "80"
  backend_service = google_compute_region_backend_service.wallarm_http.id
}

