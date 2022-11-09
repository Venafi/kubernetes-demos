# EKS and cert-manager MVP demo (addendum)

## Configure Route53 (from the CLI)

Start by setting variables to represent the ELB and DNS record name you wish to target.
```bash
elb_dnsname=$(kubectl -n ingress-nginx get service ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
hosted_zone=jetstack.mcginlay.net   # IMPORTANT - adjust as appropriate
record_subdomain_name=www$(date +"%d") # e.g. www01 - where the digits indicate the day of the month
dns_record_name=${record_subdomain_name}.${hosted_zone}
```

Now use the `hosted_zone` and `elb_dnsname` settings to configure Route53.
```bash
hosted_zone_id=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${hosted_zone}.'].Id" --output text | cut -d '/' -f3)
hosted_zone_id_for_elb=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?DNSName=='${elb_dnsname}'].CanonicalHostedZoneNameID" --output text)

action=UPSERT # switch to DELETE to reverse this operation
aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch file://<(
cat << EOF
{
    "Changes": [{
        "Action": "${action}",
        "ResourceRecordSet": {
            "Name": "${dns_record_name}",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "${hosted_zone_id_for_elb}",
                "DNSName": "dualstack.${elb_dnsname}.",
                "EvaluateTargetHealth": false
            }
        }
    }]
}
EOF
)
```

Next: [Main Menu](/README.md) | [03. EKS with ingress-nginx and cert-manager](../../03-eks-ingress-nginx-cert-manager/README.md)
