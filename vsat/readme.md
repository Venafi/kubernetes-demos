
STEPS:
NOTE: It is assumed that tlspk / cert-manager is already installed in the cluster.
1. Update all deployment manifests to reflect correct images and the digest
2. update all deployment descriptors to reflect the correct registry secret
2. Copy the pairing code from the UI and then run a curl to the following 
curl -X POST -H "Content-Type: application/json" -d '{"pairingCode":"REPLACE-ME", "location":"REPLACE ME with clueters API IP" }' https://vsat-gw.venafi.cloud/v1/edgeinstances/registration 
3. Replace client-credentials.json in bootstrap with client-credentials.json value returned in the above step
4. Apply the following manifests
    namespaces.yaml
    busybox.yaml
    vsat-cert-policy-rbac.yaml
5. Deploy manifests in the bootstrap-service followed by platform-service
6. Deploy manifests in other folders.


Images:

For redis:
docker.io/bitnami/redis:6.2.6-debian-10-r21
For Vsat (our images from public ecr):
public.ecr.aws/venafi-vsatellite/authentication-svc@sha256:3c6682a130b28650375956c4aaac590ab42fcaf1d5ea87925f28a4cd1e4f3f2e
public.ecr.aws/venafi-vsatellite/messaging-svc@sha256:7bed561b874845fcd79d005d8f143813eda833dc4476bf3ec9c0c5784a381a2f
public.ecr.aws/venafi-vsatellite/crypto-svc@sha256:a2ff2ceb8a852a3c5db08aab9f7539dbf736f605191a273b4f93e4cecfbf75c9
public.ecr.aws/venafi-vsatellite/worker-svc@sha256:092f750df0b93e59b4738e632228eed3fa66fbbe5bba2f02bce232d01ab3110b
public.ecr.aws/venafi-vsatellite/status-svc@sha256:f1c2223a0a647bdf57e21c7334d48731c17fe3a79b470f5f303298f0f182f5a3
public.ecr.aws/venafi-vsatellite/key-svc@sha256:d985fb96abf93a6427a61fcbdeb130df6a9419f54522cc5202504a191eec0e39
public.ecr.aws/venafi-vsatellite/acme-svc@sha256:4ee32d91309fc893d95882601ba7c97866586f506611d0035ae9d8fdf861df13
public.ecr.aws/venafi-vsatellite/scanafi-svc-internal@sha256:eecca1fe578b89a9b8ab3bdb02c5dcdd0aef67406c5fd51e8c9f4afbae5e7878