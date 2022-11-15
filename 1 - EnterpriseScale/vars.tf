variable "root_id" {
  type    = string
  default = "ap"
}

variable "root_name" {
  type    = string
  default = "Enterprise-Scale"
}

variable "deploy_identity_resources" {
  type    = bool
  default = true
}

variable "deploy_management_resources" {
  type    = bool
  default = true
}

variable "log_retention_in_days" {
  type    = number
  default = 50
}

variable "security_alerts_email_address" {
  type    = string
  default = "my_valid_security_contact@replace.me"
}

variable "management_resources_location" {
  type    = string
  default = "eastus2"
}

variable "management_resources_tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}