# Frontdoor-Appgw-Private-Endpoint-Storage

Storage account being the backend of the AppGW via Private endpoint, and the AppGW will be the endpoint of the Frontdoor.

Interesting case scenario with the storage account. Since it is not providing a website but files, we need to have the entire link of the file we are trying to access here.

Below we have the URL from each resources from the storage account to the Frontdoor. A SSL certificate was used on the AppGW and a AFD managed certificate was used on the Frontdoor to enable the custom domain.

- **Storage URL:** <https://appgwblobstonetdata2022.blob.core.windows.net/media/cloud-automation-logo.png>
- **AppGW URL:** <https://data.ced-sougang.com/media/cloud-automation-logo.png>
- **Frontdoor URL:** <https://media.ced-sougang.com/media/cloud-automation-logo.png>

# Architecture

![Architecture](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/Architecture.png)

This lab consists of:

- A Front door
- An Application Gateway
- A VNET
- A Storage account
- SSL certificate
- Private Endpoint

Enabling the frontdoor custom domain:

```TypeScript
az network front-door frontend-endpoint enable-https --front-door-name appgwsto-afd
                                                     --name media.ced-sougang.com
                                                     --resource-group appgwsto-rg
                                                     --certificate-source FrontDoor
                                                     --minimum-tls-version 1.2
```
