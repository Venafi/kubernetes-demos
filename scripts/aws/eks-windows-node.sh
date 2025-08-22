#!/bin/bash
set -euo pipefail

ACTION="${1:-}"
CONFIG_FILE="${2:-./env-vars.sh}"

usage() {
  cat <<USAGE
Usage: $0 {add|remove|test} [./env-vars.sh]
USAGE
  exit 1
}

[[ -z "$ACTION" ]] && usage

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi
echo "📄 Using config: $CONFIG_FILE"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

ensure_aws_auth() {
  echo "🔐 Verifying AWS authentication (profile: ${PROFILE:-default}, region: ${REGION:-unset})..."
  if ! AWS_PROFILE="${PROFILE:-default}" AWS_REGION="${REGION:-}" aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS authentication failed. Check your credentials/profile/region and try again."
    exit 1
  fi
}

# --- Find the cluster IAM role name. Can be set in env-vars.sh too ---
resolve_cluster_role_name() {
  if [[ -n "${EKS_CLUSTER_ROLE_NAME:-}" ]]; then
    echo "🔎 Cluster role pre-set: $EKS_CLUSTER_ROLE_NAME"
    return
  fi

  echo "🔎 Discovering cluster IAM role name from EKS API…"
  # Get the role ARN via EKS
  local role_arn
  role_arn=$(AWS_PROFILE="$PROFILE" AWS_REGION="$REGION" aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --query 'cluster.roleArn' \
    --output text 2>/dev/null || true)

  if [[ -z "$role_arn" || "$role_arn" == "None" ]]; then
    echo "⚠️  Could not determine cluster.roleArn from EKS for cluster '$CLUSTER_NAME'."
    echo "    You can set EKS_CLUSTER_ROLE_NAME in env-vars-win.sh to override."
    return 1
  fi

  EKS_CLUSTER_ROLE_NAME="${role_arn##*/}"

  # Verify role exists
  if ! AWS_PROFILE="$PROFILE" aws iam get-role --role-name "$EKS_CLUSTER_ROLE_NAME" >/dev/null 2>&1; then
    echo "⚠️  Discovered role '$EKS_CLUSTER_ROLE_NAME' not found in IAM."
    echo "    Set EKS_CLUSTER_ROLE_NAME explicitly if this is a cross-account or custom setup."
    return 1
  fi

  echo "✅ Discovered cluster role: $EKS_CLUSTER_ROLE_NAME"
  export EKS_CLUSTER_ROLE_NAME
}

configure_windows_networking() {
  echo "🔧 Configure Windows networking…"

  # 1) Check that the cluster role has AmazonEKSVPCResourceController
  if resolve_cluster_role_name; then
    local POLICY_ARN="arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    # Check if already attached (returns 0 or 1)
    local attached_count
    attached_count=$(AWS_PROFILE="$PROFILE" aws iam list-attached-role-policies \
      --role-name "$EKS_CLUSTER_ROLE_NAME" \
      --query "length(AttachedPolicies[?PolicyArn=='${POLICY_ARN}'])" \
      --output text || echo "0")

    if [[ "$attached_count" == "0" ]]; then
      echo "🔐 Attaching IAM policy AmazonEKSVPCResourceController to '$EKS_CLUSTER_ROLE_NAME'…"
      AWS_PROFILE="$PROFILE" aws iam attach-role-policy \
        --role-name "$EKS_CLUSTER_ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
    else
      echo "ℹ️  IAM policy already attached to '$EKS_CLUSTER_ROLE_NAME'."
    fi
  else
    echo "ℹ️  Skipping IAM policy attach (role autodiscovery failed and EKS_CLUSTER_ROLE_NAME not set)."
  fi

  # 2) Enable Windows IPAM and prefix delegation using ConfigMap
  local patch='{"data":{"enable-windows-ipam":"true"}}'
  if [[ "${ENABLE_WINDOWS_PREFIX_DELEGATION:-false}" == "true" ]]; then
    patch='{"data":{"enable-windows-ipam":"true","enable-windows-prefix-delegation":"true"}}'
  fi

  if ! kubectl -n kube-system get configmap amazon-vpc-cni >/dev/null 2>&1; then
    echo "📝 Creating amazon-vpc-cni ConfigMap with Windows flags…"
    if [[ "${ENABLE_WINDOWS_PREFIX_DELEGATION:-false}" == "true" ]]; then
      kubectl -n kube-system create configmap amazon-vpc-cni \
        --from-literal=enable-windows-ipam=true \
        --from-literal=enable-windows-prefix-delegation=true
    else
      kubectl -n kube-system create configmap amazon-vpc-cni \
        --from-literal=enable-windows-ipam=true
    fi
  else
    echo "📝 Patching amazon-vpc-cni ConfigMap…"
    kubectl -n kube-system patch configmap amazon-vpc-cni --type merge -p "$patch"
  fi

  echo "🔎 Effective values:"
  kubectl -n kube-system get configmap amazon-vpc-cni -o jsonpath='{.data.enable-windows-ipam}{" "}{.data.enable-windows-prefix-delegation}{"\n"}' || true
  echo "✅ Windows networking prerequisites ensured."
}

create_windows_nodegroup() {
  echo "🪟 Creating managed Windows node group '$WINDOWS_NODEGROUP_NAME'…"
  local cmd=(eksctl create nodegroup
    --cluster "$CLUSTER_NAME"
    --region "$REGION"
    --name "$WINDOWS_NODEGROUP_NAME"
    --managed
    --node-type "$WINDOWS_NODE_TYPE"
    --nodes "$WINDOWS_NODES"
    --nodes-min "$WINDOWS_NODES_MIN"
    --nodes-max "$WINDOWS_NODES_MAX"
    --node-ami-family "$WINDOWS_AMI_FAMILY"
    --node-volume-size "$WINDOWS_VOLUME_SIZE"
    --profile "$PROFILE"
  )
  [[ -n "${WINDOWS_LABELS:-}" ]] && cmd+=(--node-labels "$WINDOWS_LABELS")
  [[ -n "${WINDOWS_TAINTS:-}" ]] && cmd+=(--taints "$WINDOWS_TAINTS")

  echo "🧱 Running: ${cmd[*]}"
  "${cmd[@]}"
  echo "ℹ️  Target Windows workloads with: spec.nodeSelector: { kubernetes.io/os: windows }"
}

delete_windows_nodegroup() {
  echo "🗑️  Deleting Windows node group '$WINDOWS_NODEGROUP_NAME' (managed)…"
  eksctl delete nodegroup \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --name "$WINDOWS_NODEGROUP_NAME" \
    --profile "$PROFILE" \
    --approve \
    --wait
}

test_windows_workload() {
  echo "🧪 Deploying sample Windows pod…"
  cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: my-win-pod
spec:
  nodeSelector:
    kubernetes.io/os: windows
    kubernetes.io/arch: amd64
  containers:
  - name: my-container
    image: mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022
    command: ["powershell","-Command","Start-Sleep -Seconds 600"]
  restartPolicy: Never
YAML

  echo "⏳ Waiting up to 5m for pod to be Ready…"
  if ! kubectl wait --for=condition=Ready pod/my-win-pod --timeout=5m >/dev/null; then
    echo "❌ Windows pod did not become Ready. Describe events:"
    kubectl describe pod/my-win-pod || true
    exit 1
  fi
  kubectl get pod my-win-pod -o wide
  echo "✅ Windows node validated."
}

ensure_aws_auth

case "$ACTION" in
  add)
    configure_windows_networking
    create_windows_nodegroup
    ;;
  remove)
    delete_windows_nodegroup
    ;;
  test)
    test_windows_workload
    ;;
  *)
    usage
    ;;
esac
