#!/usr/bin/env bash
# EKS SNP nodegroup helper (add | delete | test)
set -eu

# ---- Load env  ----
[ -f "${ENV_VARS_FILE:-./env-vars.sh}" ] && . "${ENV_VARS_FILE:-./env-vars.sh}"
[ -f "${ENV_VARS_SNP_FILE:-./env-vars-snp.sh}" ] && . "${ENV_VARS_SNP_FILE:-./env-vars-snp.sh}"

# ---- Normalize common names ----
[ -z "${AWS_REGION:-}" ] && [ -n "${REGION:-}" ] && AWS_REGION="$REGION"
[ -z "${CLUSTER_NAME:-}" ] && [ -n "${CLUSTER:-}" ] && CLUSTER_NAME="$CLUSTER"
[ -z "${AWS_PROFILE:-}" ] && [ -n "${PROFILE:-}" ] && AWS_PROFILE="$PROFILE"
[ -z "${K8S_VERSION:-}" ] && [ -n "${KUBERNETES_VERSION:-}" ] && K8S_VERSION="$KUBERNETES_VERSION"

# ---- Required ----
: "${CLUSTER_NAME:?Set CLUSTER_NAME or CLUSTER}"
: "${AWS_REGION:?Set AWS_REGION or REGION}"

# ---- Defaults (simple) ----
AWS_PROFILE="${AWS_PROFILE:-}"
K8S_VERSION="${K8S_VERSION:-}"
SNP_NODEGROUP_NAME="${SNP_NODEGROUP_NAME:-snp-ng}"
SNP_LT_NAME="${SNP_LT_NAME:-${CLUSTER_NAME}-${SNP_NODEGROUP_NAME}-lt}"
SNP_MIN="${SNP_MIN:-1}"
SNP_DESIRED="${SNP_DESIRED:-1}"
SNP_MAX="${SNP_MAX:-2}"
SNP_INSTANCE_TYPE="${SNP_INSTANCE_TYPE:-}"     # if empty, auto-pick an SNP-capable type
SNP_DISK_SIZE_GIB="${SNP_DISK_SIZE_GIB:-40}"
SNP_AMI_ID="${SNP_AMI_ID:-}"                   # leave empty to let eksctl pick AL2023 automatically

# Optional networking
SNP_SUBNET_IDS="${SNP_SUBNET_IDS:-}"           # csv
SNP_SG_IDS="${SNP_SG_IDS:-}"                   # csv

# Optional: also delete LT on 'delete'
SNP_DELETE_LT="${SNP_DELETE_LT:-yes}"           # yes | no

# ---- echo helpers ----
print_msg() { printf "%s\n" "$*" >&2; }
print_error()  { printf "ERROR: %s\n" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || print_error "Missing dependency: $1"; }

need aws; need eksctl; need jq

awscli() {
  if [ -n "$AWS_PROFILE" ]; then
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@"
  else
    aws --region "$AWS_REGION" "$@"
  fi
}

sanitize() {
  # strip CR, non-printables, ANSI, tabs->spaces (for YAML/LT safety)
  printf '%s' "$1" \
    | tr -d '\r' \
    | tr -cd '\11\12\15\40-\176' \
    | sed $'s/\t/  /g; s/\x1B\[[0-9;]*[A-Za-z]//g'
}

get_cluster_version() {
  [ -n "$K8S_VERSION" ] && { printf '%s\n' "$K8S_VERSION"; return; }
  awscli eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.version' --output text
}

pick_snp_instance_type() {
  # If SNP_PREFER_CHEAPEST=yes (default), pick the absolute lowest vCPU, then lowest memory.
  # Otherwise, honor SNP_FAMILY_PREFERENCES order (first matching, cheapest within that family).
  : "${SNP_PREFER_CHEAPEST:=yes}"
  : "${SNP_FAMILY_PREFERENCES:=m6a c6a r6a}"

  # Pull type + vcpu + mem for all SNP-capable types in-region
  j="$(awscli ec2 describe-instance-types \
        --filters "Name=processor-info.supported-features,Values=amd-sev-snp" \
        --query 'InstanceTypes[].{Type:InstanceType,VCpu:VCpuInfo.DefaultVCpus,Mem:MemoryInfo.SizeInMiB}' \
        --output json 2>/dev/null || true)"

  [ -n "$j" ] && [ "$j" != "[]" ] || return 1

  if [ "$SNP_PREFER_CHEAPEST" = "yes" ]; then
    # sort by vCPU, then memory, then type name
    printf '%s\n' "$j" | jq -r 'sort_by(.VCpu, .Mem, .Type) | .[0].Type'
    return $?
  fi

  # Family-ordered cheapest: for each family, pick the smallest (vcpu, mem)
  for fam in $SNP_FAMILY_PREFERENCES; do
    t="$(printf '%s\n' "$j" \
        | jq -r --arg f "$fam" '
            [ .[] | select(.Type | startswith($f)) ]
            | sort_by(.VCpu, .Mem, .Type) | (.[0].Type // empty)
          ')"
    if [ -n "$t" ]; then
      printf '%s\n' "$t"
      return 0
    fi
  done

  printf '%s\n' "$j" | jq -r 'sort_by(.VCpu, .Mem, .Type) | .[0].Type'
}

ensure_launch_template() {
  ami="$1"        # may be empty -> we won't set ImageId in LT
  itype="$2"

  tmp="$(mktemp)"
  {
    echo "{"
    if [ -n "$ami" ]; then
      echo "  \"ImageId\": \"${ami}\","
    fi
    cat <<EOF
  "InstanceType": "${itype}",
  "CpuOptions": { "AmdSevSnp": "enabled" },
  "BlockDeviceMappings": [
    { "DeviceName": "/dev/xvda",
      "Ebs": { "VolumeSize": ${SNP_DISK_SIZE_GIB}, "VolumeType": "gp3", "DeleteOnTermination": true } }
  ],
  "MetadataOptions": { "HttpTokens": "required", "HttpPutResponseHopLimit": 2 }
}
EOF
  } > "$tmp"

  # Optional ENI
  if [ -n "$SNP_SUBNET_IDS" ] || [ -n "$SNP_SG_IDS" ]; then
    ni='{"DeviceIndex":0,"AssociatePublicIpAddress":false}'
    if [ -n "$SNP_SUBNET_IDS" ]; then
      first_subnet="$(printf "%s" "$SNP_SUBNET_IDS" | awk -F, '{print $1}')"
      ni="$(printf '%s' "$ni" | jq --arg s "$first_subnet" '. + {SubnetId:$s}')"
    fi
    if [ -n "$SNP_SG_IDS" ]; then
      sgs_json="$(printf '%s' "$SNP_SG_IDS" | awk -F, '{for(i=1;i<=NF;i++) printf (i>1?",":"") "\""$i"\""}')"
      ni="$(printf '%s' "$ni" | jq --argjson g "[$sgs_json]" '. + {Groups:$g}')"
    fi
    jq --argjson ni "$ni" '.NetworkInterfaces=[ $ni ]' "$tmp" > "${tmp}.n" && mv "${tmp}.n" "$tmp"
  fi

  lt_id="$(awscli ec2 describe-launch-templates \
      --filters "Name=launch-template-name,Values=${SNP_LT_NAME}" \
      --query 'LaunchTemplates[0].LaunchTemplateId' --output text 2>/dev/null || true)"

  if [ -z "$lt_id" ] || [ "$lt_id" = "None" ]; then
    print_msg "Creating Launch Template: ${SNP_LT_NAME}"
    lt_id="$(awscli ec2 create-launch-template \
      --launch-template-name "${SNP_LT_NAME}" \
      --version-description "EKS SNP v1" \
      --launch-template-data "file://$tmp" \
      --query 'LaunchTemplate.LaunchTemplateId' --output text)"
    lt_ver="1"
  else
    print_msg "Creating new Launch Template version for: ${SNP_LT_NAME}"
    lt_ver="$(awscli ec2 create-launch-template-version \
      --launch-template-id "$lt_id" \
      --version-description "EKS SNP $(date +%Y%m%d%H%M%S)" \
      --launch-template-data "file://$tmp" \
      --query 'LaunchTemplateVersion.VersionNumber' --output text)"
    awscli ec2 modify-launch-template --launch-template-id "$lt_id" --default-version "$lt_ver" >/dev/null
  fi

  rm -f "$tmp"
  printf '%s %s\n' "$(sanitize "$lt_id")" "$(sanitize "$lt_ver")"
}

write_yaml_and_apply() {
  lt_id="$(sanitize "$1")"
  lt_ver="$(sanitize "$2")"

  CLUSTER_NAME="$(sanitize "$CLUSTER_NAME")"
  AWS_REGION="$(sanitize "$AWS_REGION")"
  SNP_NODEGROUP_NAME="$(sanitize "$SNP_NODEGROUP_NAME")"
  SNP_MIN="$(sanitize "$SNP_MIN")"
  SNP_DESIRED="$(sanitize "$SNP_DESIRED")"
  SNP_MAX="$(sanitize "$SNP_MAX")"

  tmp_yaml="$(mktemp)"

  if [ -n "$SNP_AMI_ID" ]; then
    cat <<YAML > "$tmp_yaml"
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: "${CLUSTER_NAME}"
  region: "${AWS_REGION}"
managedNodeGroups:
  - name: "${SNP_NODEGROUP_NAME}"
    minSize: ${SNP_MIN}
    desiredCapacity: ${SNP_DESIRED}
    maxSize: ${SNP_MAX}
    privateNetworking: true
    launchTemplate:
      id: "${lt_id}"
      version: "${lt_ver}"
YAML

  else
    # CASE 2: eksctl-managed EKS AMI (AL2023 or Ubuntu family)
    cat <<YAML > "$tmp_yaml"
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: "${CLUSTER_NAME}"
  region: "${AWS_REGION}"
managedNodeGroups:
  - name: "${SNP_NODEGROUP_NAME}"
    amiFamily: ${SNP_AMI_FAMILY}
    minSize: ${SNP_MIN}
    desiredCapacity: ${SNP_DESIRED}
    maxSize: ${SNP_MAX}
    privateNetworking: true
    launchTemplate:
      id: "${lt_id}"
      version: "${lt_ver}"
YAML
  fi

  print_msg "Creating managed nodegroup via eksctl..."
  eksctl create nodegroup -f "$tmp_yaml"
  rm -f "$tmp_yaml"
}


add_cmd() {
  print_msg "Adding SNP nodegroup '${SNP_NODEGROUP_NAME}' to cluster '${CLUSTER_NAME}' (${AWS_REGION})"

  ver="$(get_cluster_version)"
  print_msg "Cluster version: $ver"

  # Let eksctl pick AL2023 AMI; only pass ImageId if SNP_AMI_ID is explicitly set
  ami=""
  if [ -n "$SNP_AMI_ID" ]; then
    ami="$SNP_AMI_ID"
    print_msg "Using custom AMI (will add bootstrap): $ami"
  else
    print_msg "Using eksctl-managed EKS AL2023 AMI (recommended)"
  fi

  if [ -n "$SNP_INSTANCE_TYPE" ]; then
    itype="$SNP_INSTANCE_TYPE"
  else
    itype="$(pick_snp_instance_type)"
    [ -n "$itype" ] || print_error "No SNP-capable instance types found in ${AWS_REGION}"
  fi
  print_msg "Instance type: $itype"

  set +e
  pair="$(ensure_launch_template "$ami" "$itype")"
  rc=$?
  set -e
  [ $rc -eq 0 ] || print_error "Failed to ensure Launch Template"

  lt_id="$(printf '%s' "$pair" | awk '{print $1}')"
  lt_ver="$(printf '%s' "$pair" | awk '{print $2}')"
  print_msg "Launch Template: $lt_id (version $lt_ver)"

  write_yaml_and_apply "$lt_id" "$lt_ver"
  print_msg "Add complete."
}

delete_cmd() {
  print_msg "Deleting SNP nodegroup '${SNP_NODEGROUP_NAME}' from cluster '${CLUSTER_NAME}'"
  eksctl delete nodegroup --cluster "$CLUSTER_NAME" --name "$SNP_NODEGROUP_NAME" --region "$AWS_REGION" || print_error "eksctl delete failed"

  if [ "$SNP_DELETE_LT" = "yes" ]; then
    print_msg "SNP_DELETE_LT=yes -> deleting Launch Template '${SNP_LT_NAME}'"
    lt_id="$(awscli ec2 describe-launch-templates \
      --filters "Name=launch-template-name,Values=${SNP_LT_NAME}" \
      --query 'LaunchTemplates[0].LaunchTemplateId' --output text 2>/dev/null || true)"
    if [ -n "$lt_id" ] && [ "$lt_id" != "None" ]; then
      # Delete LT (versions auto-removed with it)
      awscli ec2 delete-launch-template --launch-template-id "$lt_id" >/dev/null || true
      print_msg "Launch Template deleted: $SNP_LT_NAME"
    else
      print_msg "Launch Template not found: $SNP_LT_NAME (skipping)"
    fi
  fi

  print_msg "SNP nodegroup delete complete."
}

test_cmd() {
  print_msg "Testing SNP on nodegroup '${SNP_NODEGROUP_NAME}'"
  j="$(awscli ec2 describe-instances \
      --filters "Name=tag:eks:nodegroup-name,Values=${SNP_NODEGROUP_NAME}" "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,Cpu:CpuOptions}' \
      --output json 2>/dev/null || true)"

  [ -n "$j" ] && [ "$j" != "[]" ] || print_error "No running instances found for nodegroup '${SNP_NODEGROUP_NAME}'."

  echo "$j" | jq -r '.[] | "\(.Id)\t\(.Type)\tSNP=\(.Cpu.AmdSevSnp // "absent")"'

  bad="$(echo "$j" | jq '[ .[] | select(.Cpu.AmdSevSnp != "enabled") ] | length')"
  [ "$bad" -eq 0 ] || print_error "One or more instances DO NOT have AmdSevSnp=enabled."
  print_msg "All instances report AmdSevSnp=enabled."
}

cmd="${1:-}"
case "$cmd" in
  add)    add_cmd ;;
  remove) delete_cmd ;;
  test)   test_cmd ;;
  *)      printf "Usage: %s {add|remove|test}\n" "$(basename "$0")"; exit 1 ;;
esac
