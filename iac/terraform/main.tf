# Create Azure Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_service_plan" "asp" {
  count               = var.enable_web_app == true ? 1 : 0
  name                = var.app_svc_plan
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.app_svc_plan_sku_name
}

resource "azurerm_linux_web_app" "example" {
  count               = var.enable_web_app == true ? 1 : 0
  name                = var.app_svc_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp[count.index].id

  site_config {}
}
