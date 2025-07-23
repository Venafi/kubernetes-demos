# CyberArk Certificate Manager with venafi-pki-backend for Vault

## Prerequisites
- You have access to CyberArk Certificate Manager
- You have configured a Certificate Authority, Issuing templates and an application 
- This script is not generic (sorry!). If you are not using MacOS Silicon, you will need to make some adjustments to download the correct binaries

This demo will install vault, configure vault with venafi-pki-backend and request certificates using vault that will be fulfilled by CyberArk Certificate Manager 

## Configure the environment 
Copy `env-vars-template.sh` as `env-vars.sh` and set the variables. You won't have to change anything other than that is set as `REPLACE_WITH..`

## Step 1 - Start Vault

To keep the demo simple, we will download vault, the pki backend and run it from local machine

Run `./01.start-vault.sh` and you will see the following output 

```
❯ ./01.start-vault.sh
📥 Downloading Vault for macOS ARM...
📥 Downloading Cyberark Certificate Manager Vault plugin ZIP...
🔐 Calculating SHA256 of plugin...
🚀 Starting Vault server...
🔑 Initializing Vault...
🔓 Unsealing Vault...
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
.....
.....
```

Vault UI can be accessed with http://127.0.0.1/ui if you want to test. The token to login is in `keys.json`  

## Step 2 - Request Certificate 
To request a certificate you can simply run `./02.request-cert.sh` . Review the file before you run to understand what it is doing. This script configures the pki backend, sets up the issuer and requests a certificate. The certificate is printed for preview. 

```
❯ ./02.request-cert.sh
📌 Registering CyberArk Certificate Manager OSS plugin (venafi-pki-backend)...
Success! Registered plugin: venafi-pki-backend
📦 Checking if secrets engine is already enabled at: cyberark-cm/
📦 Enabling plugin at mount path: cyberark-cm/
Success! Enabled the venafi-pki-backend secrets engine at: cyberark-cm/
⚙️ Configuring issuer with Cyberark Certificate Manager...
Success! Data written to: cyberark-cm/venafi/vaas
📘 Defining role..
Success! Data written to: cyberark-cm/roles/vaas
📄 Requesting certificate for cert-4621302207.example.com...
📜 Certificate Preview:
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            66:7f:65:25:b8:15:b1:2e:ae:b9:5b:3f:e9:0e:e5:46:84:12:e5:e3
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, O=Venafi, Inc., OU=Built-in, CN=Dedicated - Venafi Cloud Built-In Intermediate CA - G1
        Validity
            Not Before: Jul 23 02:30:20 2025 GMT
            Not After : Jul 24 02:30:50 2025 GMT

✅ Certificate issued and saved:
-rw-r--r--  1 sitaram.iyer  staff   3.0K Jul 22 21:30 ca.pem
-rw-r--r--  1 sitaram.iyer  staff   1.7K Jul 22 21:30 cert.pem
-rw-r--r--  1 sitaram.iyer  staff   1.7K Jul 22 21:30 key.pem
```
Access CyberArk Certificate Manager UI and you will see this certificate in the inventory. Run `./02.request-cert.sh` as many times as you want. You will see new certs in the inventory. 

## Step 3 - Cleanup 

Simply run `./03.cleanup.sh` to stop vault, clean up all the files and directories created in the previous steps. The certs will still be in the CyberArk Certificate Manager inventory. Retire and delete them if you prefer. 

```
❯ ./03.cleanup.sh
🧽 Cleaning up...
✅ Clean up complete.
```