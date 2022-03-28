output "storage-account" {

  value = azurerm_storage_account.appgw-sto.name

}

#output "pe-fqdn" {

#  value = azurerm_private_dns_a_record.appgw-a-record.fqdn
  
#}