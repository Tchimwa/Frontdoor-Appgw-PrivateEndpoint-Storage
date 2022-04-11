# Leveraging Azure Front Door to expose some blob containers globally

In this lab, we will show how to configure an Azure Front Door and an application Gateway in front of a storage account using Private Endpoint, to better expose the storage containers globally and secure access to them with custom domains.

## Introduction

Azure Front Door delivers your content using the global and local POPs distributed around the world close to ends users. Usually Front Door needs public VIP or a publicly available DNS name to route the traffic to, so it supports most of the PaaS services. This scenario is special as the customer here is looking to limit access to his storage account using the Private endpoint, but also would like the content of his blob containers to be available globally. The solution here will be to have an Application gateway in from of the storage account using the private endpoint, then use the AppGW as endpoint of the Front Door to make the blobs available publicly.
When I was working on this lab, the new Azure Front Door wasn't available yet as it currently supports Private Link on a few regions. We'll study the case with the AppGW + Front Door first, then we will work on the case scenario with the Front Door + PrivateLInk to the storage account directly.

## Prerequisites and architecture

To complete this lab, there is no much needs beside of what is listed below:

- Valid Azure subscription
- Git
- SSL certificate for the AppGW and the Front Door custom domain(optional, we can use the Azure managed certificate here) from a well-known CA

Architecture will be as simple as it is shown below:
![Architecture](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/Architecture.png)

## Deployment and configuration

The terraform template has most of the essential configuration already, but we will review the most important points of the lab for more clarity. Feel free to clone the repo and use your own SSL certificate to deploy it.  

```typescript
git clone https://github.com/Tchimwa/Frontdoor-Appgw-PrivateEndpoint-Storage.git
cd ./Frontdoor-Appgw-PrivateEndpoint-Storage
terraform init
terraform plan 
terraform apply
```

## Storage account

Limit access to your storage account publicly and only allow the subnet hosting the AppGW and your public IP for the storage account management. With this set up, access will only be allowed to the AppGW. This  can be done by accessing the ***Networking*** tab on the left panel of the storage account page.
![StorageFW](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/StorageFirewalls.png)

From the "Configuration" tab, leave the default value set for the TLS (which is 1.2 and will be the same use on the Front door and the AppGW) and the secure transfer and make sure that  "**Allow Blob public access**" is set to "**Enabled**"
![BlobAccess](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/BlobAccess.png)

Let's make sure that we have our private endpoint successfully set up on the Storage account. Use the ***Networking*** tab, and select "**Private endpoint connections**"
![pe](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/pe.png)

Private endpoint DNS configuration :
![pednsconf](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/pednsconf.png)

## Application Gateway

When it comes to the AppGW configuration, some of the configuration here will depends on your own flavors. I chose to have a **Multisite** type listener just in case I would like to add more backend targets in the future, but as of now we only one hostname which is "**data.ced-sougang.com**" and of course we are doing HTTPS so Port 443. I would like to mention that ven the "**Basic**" type should have worked in this case scenario!
![AppgwListener](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/AppgwListener.png)

When it comes to the HTTPS settings, the most important point will be the well-known domain "**blob.core.windows.net**" that belongs to Microsoft and consequently its certificate is recognized by the AppGW as provided by a well-known CA. This is actually preventing you to upload any root trusted certificate for your HTTPS settings.
![WellKnownCA](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/WellKnownCA.png)

Now, the custom probe use on the HTTP settings is quite interesting due to the fact that the storage account is not a website, so it will not return the HTTP 200 OK that we're all accustomed to.

- From the public access, you will be receiving an HTTP error response 400 as it is shown below from the browser Dev tools
    ![DevToolError](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/DevToolError.png)
- If you choose to have a private frontend IP on the AppGW, you will be receiving a 409 HTTPS response instead of the 400
Based on those 2 response codes, we can set up or custom probe to match with them so the requests can forwarded to the Storage account when they come in.
    ![CustomProbe](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/CustomProbe.png)
As result, we have the result below since the HTTP error codes are expected. Mine is showing 400 because I do have a public frontend IP configuration on my AppGW.
    ![ProbeResult](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/ProbeResult.png)

As result, we have a successful access to the Storage file through the AppGW :

A CNAME record was already created with the public IP of the AppGW and the hostname "**data.ced-sougang.com**".

**AppGW URL:** <https://data.ced-sougang.com/media/cloud-automation-logo.png>

```typescript
C:\Users\tcsougan>curl -I https://data.ced-sougang.com/media/cloud-automation-logo.png
HTTP/1.1 200 OK
Date: Mon, 11 Apr 2022 16:45:54 GMT
Content-Type: image/png
Content-Length: 40080
Connection: keep-alive
Content-MD5: HGv9IhxMvhtR+IS7npkLog==
Last-Modified: Mon, 28 Mar 2022 04:31:55 GMT
ETag: 0x8DA1073E3E197DE
Server: Windows-Azure-Blob/1.0 Microsoft-HTTPAPI/2.0
x-ms-request-id: e57426e7-501e-0011-61c3-4db674000000
x-ms-version: 2009-09-19
x-ms-lease-status: unlocked
x-ms-blob-type: BlockBlob
```

A connection troubleshoot on the storage account FQDN from the AppGW confirms that the AppGw is currently using the Private endpoint set up on the storage account:
![ConnectionTB](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/ConnectionTB.png)

## Front Door configuration

A Front Door classic is the Tier used in this first configuration. Add the backend pool with a full path to a file available in the blob for the Health Probe to be successful. AFD doesn't support any other response beside the 200 OK for a successful probe. There is no way to customized the matching code as we do with the AppGW.
![AFDBEPool](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/AFDBEPool.png)

The backend host type here will be "Custom Host", and the hostname will be the hostname of the AppGW as well as the backend host header.
![AFDBackend](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/AFDBackend.png)

Enabling the frontdoor custom domain "media.ced-sougang.com":

```TypeScript
az network front-door frontend-endpoint enable-https --front-door-name appgwsto-afd
                                                                                         --name media.ced-sougang.com
                                                                                         --resource-group appgwsto-rg
                                                                                         --certificate-source FrontDoor
                                                                                         --minimum-tls-version 1.2
```

On the afd-rule routing rule which is the principal rule, the Accepted protocol will be "HTTPS Only" as well as the forwarding protocol. I also configured a second rule to redirect HTTP to HTTPS as well.

```azurecli
az network front-door routing-rule create --front-door-name appgwsto-afd --frontend-endpoints media-ced-sougang-com 
                                                                                                                                    --custom-host media.ced-sougang.com 
                                                                                                                                    --name afd-rule-http --resource-group appgwsto-rg 
                                                                                                                                    --route-type Redirect 
                                                                                                                                    --disabled false 
                                                                                                                                    --redirect-protocol HttpsOnly 
                                                                                                                                    --redirect-type Found
                                                                                                                                    
```

As result, we have our storage account expose globally using the Azure Front Door.

**Frontdoor URL:** <https://media.ced-sougang.com/media/cloud-automation-logo.png>

```typescript
C:\Users\tcsougan>curl -I https://media.ced-sougang.com/media/cloud-automation-logo.png
HTTP/1.1 200 OK
Content-Length: 40080
Content-Type: image/png
Content-MD5: HGv9IhxMvhtR+IS7npkLog==
Last-Modified: Mon, 28 Mar 2022 04:31:55 GMT
ETag: 0x8DA1073E3E197DE
x-ms-request-id: 0f0beb1e-d01e-000f-12cb-4d5aac000000
x-ms-version: 2009-09-19
x-ms-lease-status: unlocked
x-ms-blob-type: BlockBlob
X-Cache: CONFIG_NOCACHE
X-Azure-Ref: 0NGlUYgAAAADpVziXMDlkTKGriNM0oPwCQVRMMzMxMDAwMTEwMDMxADJkMzA5NmVhLWE3MDgtNDE0Zi1hMjUzLTdjMWI3ZDIxMDU4Ng==
Date: Mon, 11 Apr 2022 17:45:23 GMT


C:\Users\tcsougan>curl -I http://media.ced-sougang.com/media/cloud-automation-logo.png
HTTP/1.1 302 Found
Content-Length: 0
Location: https://media.ced-sougang.com/media/cloud-automation-logo.png
X-Azure-Ref: 0PmlUYgAAAACg+S9DXT+hR4K5Qu5+vGZIQVRMMzMxMDAwMTA5MDM3ADJkMzA5NmVhLWE3MDgtNDE0Zi1hMjUzLTdjMWI3ZDIxMDU4Ng==
Date: Mon, 11 Apr 2022 17:45:33 GMT

```

The next point will be to use the new Azure Front Door to expose the same storage account using the Private link and getting rid of the Application Gateway.

![NewAFDArchitecture](https://github.com/Tchimwa/Frontdoor-Appgw-Storage/blob/main/images/NewAFDArchitecture.png)

Stay tuned !!!
