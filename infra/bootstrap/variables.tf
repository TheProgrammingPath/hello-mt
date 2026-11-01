variable "initials" {
  type        = string
  description = "Owner initials used in resource names, e.g. rg-hello-<initials>-dev (2 to 4 lowercase letters)."

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.initials))
    error_message = "initials must be 2 to 4 lowercase letters."
  }
}

variable "location" {
  type        = string
  description = "Azure region for every resource in this project."
  default     = "eastus"
}

variable "owner" {
  type        = string
  description = "Value of the owner tag on every resource."
}

variable "expires_on" {
  type        = string
  description = "Value of the expires-on tag (YYYY-MM-DD): the date after which these resources can be deleted."

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.expires_on))
    error_message = "expires_on must be a date in YYYY-MM-DD format."
  }
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (owner/name) whose workflows may use the OIDC identities."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}
variable "github_owner_id" {
  type        = string
  description = "Numeric ID of the GitHub repository owner (part of the OIDC subject)."
}

variable "github_repository_id" {
  type        = string
  description = "Numeric ID of the GitHub repository (part of the OIDC subject)."
}