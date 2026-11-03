variable "name" {
  type        = string
  description = "Name of the virtual network, e.g. vnet-hello-mt-dev."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the network."
}

variable "address_space" {
  type        = string
  description = "VNet address space; must be a /16 (10.10.0.0/16 dev, 10.20.0.0/16 prod)."

  validation {
    condition     = can(cidrnetmask(var.address_space)) && endswith(var.address_space, "/16")
    error_message = "address_space must be a valid /16 CIDR block, e.g. 10.10.0.0/16."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource in this module."
}
