variable "mgt_sub_id" {
    type = string
    default = "f64fc3ff-2792-4338-aa51-c97d4d388148"
}

variable "primary_region" {
    type = string
    default = "East US 2"
}

variable "secondary_region" {
    type = string
    default = "Central US"
}

variable "primary_region_cidr" {
    type = string
    default = "10.100.0.0/16"
}

variable "secondary_region_cidr" {
    type = string
    default = "10.200.0.0/16"
}

variable "primary_region_dns" {
    type = list
    default = [
        "1.1.1.1",
        "8.8.8.8"
    ]
}

variable "secondary_region_dns" {
    type = list
    default = [
        "1.1.1.1",
        "8.8.8.8"
    ]
}

variable "primary_region_subnet" {
  type = string
  default = "10.100.1.0/24"
}

variable "primary_region_gatewaysubnet" {
  type = string
  default = "10.100.2.0/24"
}

variable "primary_region_firewallsubnet" {
  type = string
  default = "10.100.3.0/24"
}

variable "secondary_region_subnet" {
  type = string
  default = "10.200.1.0/24"
}

variable "secondary_region_gatewaysubnet" {
  type = string
  default = "10.200.2.0/24"
}

variable "secondary_region_firewallsubnet" {
  type = string
  default = "10.200.3.0/24"
}


variable "log_retention" {
  type        = number
  default     = 180
}

# Tags

variable "managedby" {
  type        = string
  default     = "Terraform"
}