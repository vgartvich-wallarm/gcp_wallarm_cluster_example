provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

module "gcp_vpc" {
  source         = "./modules/gcp_vpc"
  project        = var.gcp_project
  region         = var.gcp_region
  vpc_cidr_block = var.vpc_cidr_block
  az_count       = var.az_count
  name_prefix    = var.name_prefix
}

module "gcp_wordpress" {
  source        = "./modules/gcp_wordpress"
  region        = var.gcp_region
  vpc_self_link = module.gcp_vpc.self_link
  az_count      = var.az_count
  name_prefix   = var.name_prefix
  depends_on = [
    module.gcp_vpc
  ]
}

module "gcp_wallarm" {
  source                  = "./modules/gcp_wallarm"
  region                  = var.gcp_region
  vpc_self_link           = module.gcp_vpc.self_link
  az_count                = var.az_count
  name_prefix             = var.name_prefix
  wallarm_image           = var.wallarm_image
  wallarm_deploy_username = var.wallarm_deploy_username
  wallarm_deploy_password = var.wallarm_deploy_password
  wallarm_api_domain      = var.wallarm_api_domain
  origin_ip               = module.gcp_wordpress.wordpress_lb_ip
  depends_on = [
    module.gcp_vpc,
    module.gcp_wordpress
  ]
}
