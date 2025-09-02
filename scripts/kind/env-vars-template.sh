#!/usr/bin/env bash
# Copy to env-vars.sh and customize if needed. 

# Cluster naming/image
CLUSTER_NAME_PREFIX="mis-demo-cluster"
KIND_NODE_IMAGE=""                     # e.g. "kindest/node:v1.34.0" (leave empty to use kind default)
SHOW_CONFIG=1 # Will print kind config before creating cluster

# Port mappings (comma-separated "host:container/PROTO")
# Add more by appending with a comma (e.g., ,8080:80/TCP,8443:443/TCP)
EXTRA_PORT_MAPPINGS="80:80/TCP,443:443/TCP"

# Directory (relative to this script) to read *.pem and mount into /etc/ssl/certs/<filename>
EXTRA_MOUNTS_DIR="extra-mounts"

# ---- prep-cluster: components  - WIP
#METALLB_VERSION="v0.15.2"
#INGRESS_NGINX_VERSION="v1.13.2"

# Optional explicit MetalLB pool; if blank, auto-derive from Docker 'kind' network
#POOL_START=""                          # e.g. "172.18.255.10"
#POOL_END=""                            # e.g. "172.18.255.250"