#####################################
#  API GATEWAY
######################################

variable "tags" {
  default     = {}
  description = "Map of tags to assign to this module's resources"
  type        = map(string)
}

variable "project_name" {
  default     = "ldap-maintainer"
  description = "(Optional) Name of the project"
  type        = string
}

#####################################
#  SLACK LISTENER LAMBDA
######################################

variable "slack_api_token" {
  description = "API token used by the slack client"
  default     = ""
  type        = string
}

variable "log_level" {
  default     = "Info"
  description = "Log level of the lambda output, one of: Debug, Info, Warning, Error, or Critical"
  type        = string
}

variable "slack_listener_api_endpoint_arn" {
  default     = ""
  description = ""
  type        = string
}

variable "slack_signing_secret" {
  default     = ""
  description = "The slack application's signing secret"
  type        = string
}