#!/usr/bin/env bash
# ===== Harbor =====
export HARBOR_HOST="REPLACE_WITH_DNS" #for e.g harbor.example.com
export HARBOR_USERNAME="admin" #default user
export HARBOR_PASSWORD="Harbor12345" #default password
export HARBOR_VERIFY_TLS="true"   # set "false" only if using untrusted certs

# ===== Project =====
export PROJECT_NAME="my-mirror" #Set your project name
export PROJECT_PUBLIC="false"
export PROJECT_AUTO_SCAN="true"

# ===== Robot =====
export ROBOT_NAME="ci"            # change to mint a NEW token later
export ROBOT_ACTIONS="push,pull"
export ROBOT_DURATION=-1          # -1=never; positive int per your Harbor build (often hours)

# ===== Kubernetes Secret output =====
export SECRET_NAME="harbor-creds" # Creds name that you want to generate
export NAMESPACE="default" # name space in the yaml
export DOCKER_EMAIL="noreply@example.com"
