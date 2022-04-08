# Frontdoor-Appgw-Storage

Test - Storage account being the backend of the AppGW, and the AppGW will be the endpoint of the Frontdoor.

While waiting for a certificate from a well-known CA to implement the Front Door part, we have conducted the first part using a self-signed certificate.

- **Storage URL:** <https://appgwblobstonetdata2022.blob.core.windows.net/media/cloud-automation-logo.png>
- **AppGW URL:** <https://data.ced-sougang.com/media/cloud-automation-logo.png>

# Architecture

![Architecture](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/Architecture.png)

This lab consists of:

- A Front door
- An Application Gateway
- A Storage account
- SSL certificate
- Private Endpoint
