variable "gcp_project" {
  type    = string
}

variable "gcp_region" {
  type    = string
  default = "us-west2"
}

variable "name_prefix" {
    type = string
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
    type = number
}

variable "wallarm_image" {
    type = string
    default = "wallarm-node-3-2-20210730-112042"
}

variable "wallarm_deploy_username" {
  type = string
}

variable "wallarm_deploy_password" {
  type = string
}

variable "wallarm_api_domain" {
  type    = string
  default = "us1.api.wallarm.com"
}
variable "wallarm_user_domain" {
  type    = string
  default = ""
}
