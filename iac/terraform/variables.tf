variable "rg_name" {
  type = string
}

variable "rg_location" {
  type = string
}

variable "app_svc_plan" {
  type = string
}

variable "app_svc_plan_sku_name" {
  type = string
}

variable "app_svc_name" {
  type = string
}

### Feature Flags
variable "enable_web_app" {
  default = false
  type    = bool
}