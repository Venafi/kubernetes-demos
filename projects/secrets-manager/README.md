# CyberArk Secrets Manager + Certificate Manager for issuing certificates

If you are using CyberArk Secrets Manager (Conjur) already to manage secrets, this integration allows you to seamlessly request certificates as well using the API's that you are already familiar with. 

## Pre-requisites
- You have access to CyberArk Secrets Manager and CyberArk Certificate Manager
- Certificate Authorities and Issuing Templates are created in Certificate Manager along with an Application
- Issuer is configured in CyberArk Secrets Manager. This requires creating a service account in CyberArk Identity 
- Detailed documentation is available [here](https://docs.cyberark.com/conjur-cloud/latest/en/content/operations/conjur-cloud/venafi-cert-issuer.htm)


## Configuring demo environment 
- Copy `vars-template.sh` as `vars.sh`
- Replace the values for the variables as applicable to your environment 

## Testing certificate issuance 

Review `issue-cert.sh` . This first authenticates to CyberArk secrets manager, retrieves a token and then requests a certificate from CyberArk Certificate Manager

Simply run `./issue-cert.sh` and you will see the following output

```
❯ ./issue-cert.sh
📜 Certificate Preview:
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            68:5f:bd:54:1a:99:b6:e5:1e:38:23:67:b1:bf:51:7e:fd:a7:85:d3
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=CyberArk, CN=ZTPKI Demo RSA ICA 1
        Validity
            Not Before: Jul 23 02:03:04 2025 GMT
            Not After : Jan 19 02:03:04 2026 GMT
✅ Cert saved in: /tmp/cert-0221132207.example.com
total 48
-rw-r--r--  1 sitaram.iyer  wheel   4.1K Jul 22 21:13 cert-0221132207.example.com-chain.pem
-rw-r--r--  1 sitaram.iyer  wheel   1.7K Jul 22 21:13 cert-0221132207.example.com-key.pem
-rw-r--r--  1 sitaram.iyer  wheel   2.0K Jul 22 21:13 cert-0221132207.example.com.pem
-rw-r--r--  1 sitaram.iyer  wheel   7.9K Jul 22 21:13 response.json
```
If you prefer to use terraform, change directory to `terraform` and make a copy of `terraform-template.tfvars` to `terraform.tfvars`, supply the values and run your plan and apply. Note that at this time terraform plan is using a local-exec provisioner and will be updated to use native terraform capabilities. 

## Review in the UI
Access CyberArk Certificate Manager and you will find the certificate in the inventory. 
