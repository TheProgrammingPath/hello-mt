variable "name" {
  type        = string
  description = "Name of the Log Analytics workspace, e.g. log-hello-mt-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the workspace."
}

variable "retention_in_days" {
  type        = number
  description = "How long logs are kept."
  default     = 30
}

variable "daily_quota_gb" {
  type        = number
  description = "Daily ingestion cap in GB (0.5 dev, 1 prod); ingestion stops for the day when reached."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource in this module."
}
