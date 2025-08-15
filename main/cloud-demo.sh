#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(dirname "$0")/scripts"
source "$SCRIPTS_DIR/load-variables.sh"
echo "#################################################################################"
echo "#################################################################################"
echo "[cloud-demo] Using Cyberark Certificate Manager : ${CLOUD_URL}"
echo "#################################################################################"
echo "#################################################################################"

# source "env-vars.sh"
# source "component-versions.sh"

# Utility: print usage
usage() {
  echo "Usage: $0 <command> [args...]"
  echo ""
  echo "Available commands (to be executed in order):"
  echo ""
  echo "  01.prep-env                 Prepare environment. Create temporary directories"
  echo "  02.create-service-accounts  Create CyberArk Certificate Manager Service Accounts"
  echo "  03.prep-kubernetes          Create namespaces, secrets required for demos"
  echo "  04.install [mode]           Install CyberArk Certificate Manager in the cluster"
  echo "                              Supported modes:"
  echo "                                venctl   (default) - Uses Helm and venctl"
  echo "                                operator           - Uses OLM + VenafiInstall CR"
  echo "  05.configure-demo           Create Certificate policies and issuers"
  echo "  06.create-sample-data       Seed demo environment with sample workloads and certs"
  echo "  07.install-istio-csr [mode]    Prepare and install Istio SPIFFE integration"
  echo "                                 Supported modes: venctl (default), operator"
  echo "  08.install-istio            Install and configure Istio Service Mesh"
  echo "  09.deploy-public-gateway    OPTIONAL - Deploy Gateway with TLS cert and DNS mapping"
  echo ""
  echo "  show                        Demonstrate CyberArk Certificate Manager capabilities"
  echo "                              Subcommands: issuers, policies, secrets, svid <app>, app-url, kiali-url"
  echo "                              Advanced: port_forward_service <name> <namespace> <service> <target_port> <local_port>"
  echo "  stop-port-forwards          Stop all background port forwards"
  echo ""
  echo "  clean                       OPTIONAL - Remove everything"
  echo "                              Subcommands: intermediates, configuration, configuration <config_name>"
  echo ""
  echo "Examples:"
  echo "  $0 01.prep-env"
  echo "  $0 04.install"
  echo "  $0 04.install operator"
  echo "  $0 show issuers"
  echo "  $0 show svid frontend"
  echo "  $0 show app-url"
  echo ""
  echo "NOTE: All scripts must be located in the 'scripts/' directory and be executable."
  exit 1
}


# Entry point
if [ $# -lt 1 ]; then
  usage
fi

CMD="$1"
shift

# This is to make sure stop-port-forwards can be called from top level script as opposed to show stop-port-forwards which does not read well.
if [ "$CMD" == "stop-port-forwards" ]; then
  echo "Running: stop-port-forwards"
  "$SCRIPTS_DIR/show.sh" stop-port-forwards
  exit $?
fi

# Special-case the 'show' command with flexible subcommands
if [ "$CMD" == "show" ]; then
  echo "Running: show $*"
  "$SCRIPTS_DIR/show.sh" "$@"
  exit $?
fi

# Support `clean intermediates` → purge-intermediate-certs.sh
if [ "$CMD" == "clean" ] && [ "${1:-}" == "intermediates" ]; then
  echo "Running: clean intermediates (purge intermediate certs)"
  "$SCRIPTS_DIR/purge-intermediate-certs.sh"
  exit $?
fi

# Support `clean configuration` → reset-cloud-configuration.sh
if [ "$CMD" == "clean" ] && [ "${1:-}" == "configuration" ]; then
  shift  # shift "configuration" off
  CONFIG_NAME="${1:-}"
  if [[ -n "$CONFIG_NAME" ]]; then
    "$SCRIPTS_DIR/reset-cloud-configuration.sh" "$CONFIG_NAME"
  else
    "$SCRIPTS_DIR/reset-cloud-configuration.sh"
  fi
  exit $?
fi


if [ "$CMD" == "04.install" ]; then
  echo "Running: 04.install ${1:-venctl}"
  "$SCRIPTS_DIR/04.install.sh" "${1:-venctl}"
  exit $?
fi

if [ "$CMD" == "07.install-istio-csr" ]; then
  echo "Running: 07.install-istio-csr ${1:-venctl}"
  "$SCRIPTS_DIR/07.install-istio-csr.sh" "${1:-venctl}"
  exit $?
fi

CMD_SCRIPT="$SCRIPTS_DIR/$CMD.sh"

if [ -x "$CMD_SCRIPT" ]; then
  echo "Running: $CMD"
  "$CMD_SCRIPT" "$@"
else
  echo "ERROR: Unknown or non-executable command script: $CMD"
  usage
fi
