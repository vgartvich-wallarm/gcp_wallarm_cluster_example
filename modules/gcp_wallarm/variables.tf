variable "region" {
  type = string
}

variable "name_prefix" {
    type = string
}

variable "vpc_self_link" {
    type = string
}

variable "az_count" {
    type = number
}

variable "wallarm_image" {
    type = string
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

variable "origin_ip" {
  type    = string
}
