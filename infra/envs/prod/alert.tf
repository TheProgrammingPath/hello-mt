variable "alert_email" {
  type        = string
  description = "Crash-loop alert recipient; set via TF_VAR_alert_email (GitHub variable ALERT_EMAIL)."
  sensitive   = true
}
