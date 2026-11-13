# P8.2: email the owner when containers in the hello namespace restart more than 3 times in 15 minutes.

variable "alert_email" {
  type        = string
  description = "Address that receives the crash-loop alert. Comes from the ALERT_EMAIL GitHub variable via TF_VAR_alert_email; never committed."
  sensitive   = true
}

locals {
  suffix = trimprefix(var.name, "log-")
}

resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${local.suffix}"
  resource_group_name = var.resource_group_name
  short_name          = "hello-alert"
  tags                = var.tags

  email_receiver {
    name                    = "owner-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "restarts" {
  name                    = "alert-restarts-${local.suffix}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  description             = "More than 3 container restarts in the hello namespace within 30 minutes (crash loop)."
  severity                = 2
  evaluation_frequency    = "PT5M"
  window_duration         = "PT30M"
  scopes                  = [azurerm_log_analytics_workspace.this.id]
  auto_mitigation_enabled = true
  tags                    = var.tags

  criteria {
    query                   = <<-KQL
      KubePodInventory
      | where Namespace == "hello"
      | where isnotempty(ContainerName)
      | summarize Restarts = max(ContainerRestartCount) - min(ContainerRestartCount) by PodName = Name, ContainerName
      | where Restarts > 3
    KQL
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.email.id]
  }
}
