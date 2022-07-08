# Create Azure Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_service_plan" "asp" {
  name                = var.app_svc_plan
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.app_svc_plan_sku_name
}

resource "azurerm_linux_web_app" "example" {
  name                = var.app_svc_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {}
}
