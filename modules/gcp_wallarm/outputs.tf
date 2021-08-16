output "wallarm_lb_ip" {
  value = google_compute_forwarding_rule.wallarm_http.ip_address
}
