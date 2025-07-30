# Certificate Manager for issuing certificates with service accounts mapped to IDP. 

This demo is to demonstrate requesting certificates using Certificate Manager without using an APIKey. The demo uses Okta, Azure and Auth0 but can be configured to use any OIDC provider.  

## Pre-requisites
- You have access to CyberArk Certificate Manager
- Certificate Authorities and Issuing Templates are created in Certificate Manager along with an Application
- You have followed the instructions provided [here](https://docs.venafi.cloud/vcs-platform/serviceaccounts/t-service-accounts-create-API-integration/) to create a custom API integration for your IDP. 

## Running the demo 

### Environment variables
Copy `env-vars-template.sh` as `env-vars.sh` and set the required variables

### Test

Run `./issue-cert.sh` and you will see
```
Usage: ./issue-cert.sh [okta|azure|auth0]
```

Run `./issue-cert.sh okta` and you will see 

```
❯ ./issue-cert.sh okta
🔐 Requesting certificate for CN: okta-cert-2820582907.example.com
vCert: 2025/07/29 20:58:30 Successfully connected to Venafi as a Service
vCert: 2025/07/29 20:58:30 Successfully read zone configuration for CloudApps\my-issuing-template
vCert: 2025/07/29 20:58:30 Successfully created request for okta-cert-2820582907.example.com
vCert: 2025/07/29 20:58:30 Getting CIT
vCert: 2025/07/29 20:58:30 Building policy
vCert: 2025/07/29 20:58:33 Successfully posted request for okta-cert-2820582907.example.com, will pick up by b166eb50-6ce8-11f0-9cfa-c9b56c645f40
vCert: 2025/07/29 20:58:34 Successfully retrieved request for b166eb50-6ce8-11f0-9cfa-c9b56c645f40
\n📜 Certificate Preview:
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            10:fe:53:c0:02:fc:32:1b:5e:af:bb:05:1b:59:47:0b:27:3e:09:2e
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=Venafi, Inc., OU=Built-in, CN=Dedicated - Venafi Cloud Built-In Intermediate CA - G1
        Validity
            Not Before: Jul 30 01:58:01 2025 GMT
            Not After : Oct 29 01:58:31 2025 GMT
\n✅ Cert saved in: /tmp/okta-cert-2820582907.example.com
total 40
-rw-r--r--  1 sitaram.iyer  wheel   3.0K Jul 29 20:58 okta-cert-2820582907.example.com-chain.pem
-rw-r--r--  1 sitaram.iyer  wheel   1.7K Jul 29 20:58 okta-cert-2820582907.example.com-key.pem
-rw-r--r--  1 sitaram.iyer  wheel   1.6K Jul 29 20:58 okta-cert-2820582907.example.com.pem
-rw-r--r--  1 sitaram.iyer  wheel   6.5K Jul 29 20:58 response.json
```