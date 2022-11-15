variable "primary_region" {
    type = string
    default = "East US 2"
}

variable "secondary_region" {
    type = string
    default = "Central US"
}

variable "log_retention" {
  type        = number
  default     = 180
}

variable "law_solutions" {
  default =[
    "AgentHealthAssessment",
    "AntiMalware",              
    "AzureActivity",
    "ChangeTracking",
    "Security",
    "SecurityInsights",
    "ServiceMap",
    "SQLAssessment",
    "SQLVulnerabilityAssessment",
    "SQLAdvancedThreatProtection",
    "Updates",
    "VMInsights"
  ]
}

# Tags

variable "managedby" {
  type        = string
  default     = "Terraform"
}