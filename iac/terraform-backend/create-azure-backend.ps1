[CmdletBinding()]
param (
    [Parameter()]
    [string] $randomInt = (Get-Random -Maximum 9999),
    [Parameter()]
    [string] $resourceGroupName = "rg-tf-backend-prod",
    # Parameter help description
    [Parameter()]
    [string] $location = "eastus",
    # Parameter help description
    [Parameter()]
    [string] $storageName = "tfbackendprodsa$randomInt",
    # Parameter help description
    [Parameter()]
    [string] $kvName = "tf-backend-prod-kv$randomInt",
    # Parameter help description
    [Parameter()]
    [string] $appName = "tf-prod-github-SPN$randomInt"
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

#Log into Azure
#az login

# Setup Variables.
# $randomInt = Get-Random -Maximum 9999
$subscriptionId=$(az account show --query id -o tsv)

# $storageName = "tfbackendprodsa$randomInt"
# $kvName = "tf-backend-prod-kv$randomInt"
# $appName="tf-prod-github-SPN$randomInt"
# $region = "westeurope"

# Create the resource group
az group create --name $resourceGroupName --location $location

# Create the Key Vault
az keyvault create `
    --name $kvName `
    --resource-group $resourceGroupName `
    --location $location `
    --enable-rbac-authorization

# Get the resource id of the new key vault
$keyVaultId = $(az keyvault show --name $kvName --resource-group $resourceGroupName --query id -o tsv)

# Authorize the operation to create secrets - Signed in User (Key Vault Secrets Officer)
az ad signed-in-user show --query objectId -o tsv | foreach-object {
    az role assignment create `
        --role "Key Vault Secrets Officer" `
        --assignee "$_" `
        --scope $keyVaultId
    }

# Create an azure storage account for Terraform backend
az storage account create `
    --name $storageName `
    --location $location `
    --resource-group $resourceGroupName `
    --sku "Standard_LRS" `
    --kind "StorageV2" `
    --https-only true

# Get the resource id of the new storage account
$storageAccountId = $(az storage account show --name $storageName --resource-group $resourceGroupName --query id -o tsv)

# Authorize the signed in user to create the container
az ad signed-in-user show --query objectId -o tsv | foreach-object { 
    az role assignment create `
        --role "Storage Blob Data Contributor" `
        --assignee "$_" `
        --scope $storageAccountId
    }

# Create the container in storage account to store the terraform state files
Start-Sleep -s 45
az storage container create `
    --account-name $storageName `
    --name "tfstate" `
    --auth-mode login

# Create Terraform Service Principal and assign RBAC Role on Key Vault 
$spnJSON = az ad sp create-for-rbac --name $appName `
    --role "Key Vault Secrets Officer" `
    --scopes $keyVaultId 

# Save new Terraform Service Principal details to key vault
$spnObj = $spnJSON | ConvertFrom-Json
foreach($object_properties in $spnObj.psobject.properties) {
    If ($object_properties.Name -eq "appId") {
        $null = az keyvault secret set --vault-name $kvName --name "ARM-CLIENT-ID" --value $object_properties.Value
    }
    If ($object_properties.Name -eq "password") {
        $null = az keyvault secret set --vault-name $kvName --name "ARM-CLIENT-SECRET" --value $object_properties.Value
    }
    If ($object_properties.Name -eq "tenant") {
        $null = az keyvault secret set --vault-name $kvName --name "ARM-TENANT-ID" --value $object_properties.Value
    }
}
$null = az keyvault secret set --vault-name $kvName --name "ARM-SUBSCRIPTION-ID" --value $subscriptionId

# Assign Contributor role to Terraform Service Principal and also let it access the backend storage
az ad sp list --display-name $appName --query [].appId -o tsv | ForEach-Object {
    az role assignment create --assignee "$_" `
        --role "Contributor" `
        --subscription $subscriptionId

    az role assignment create --assignee "$_" `
        --role "Storage Blob Data Contributor" `
        --scope $storageAccountId `
}
