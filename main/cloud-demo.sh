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
  echo "  02.create-service-accounts  Create CyberArk Certificate Manager Service Accounts."
  echo "  03.prep-kubernetes          Create namespaces, secrets required for demos"
  echo "  04.install                  Generate manifests and install CyberArk Certificate Manager in cluster"
  echo "  05.configure-demo           Create Certificate policies and issuers"
  echo "  06.create-sample-data       Seed demo environment with sample data"
  echo "  07.install-istio-csr        Prepare environment for istio-csr and install"
  echo "  08.install-istio            Install and configure Istio Service Mesh"
  echo "  09.deploy-public-gateway    OPTIONAL - Deploy Gateway with TLS cert and DNS mapping"
  echo "  show                        Demonstrate CyberArk Certificate Manager capabilities"
  echo "                              Subcommands: issuers, policies, secrets, svid <app>, app-url, kiali-url"
  echo "                              Advanced: port_forward_service <name> <namespace> <service> <target_port> <local_port>"
  echo "  stop-port-forwards          Stop all background port forwards"
  echo "  clean                       OPTIONAL - Remove everything"
  echo "                              Subcommands: intermediates"
  echo ""
  echo "Examples:"
  echo "  $0 01.prep-env"
  echo "  $0 show issuers"
  echo "  $0 show svid frontend"
  echo "  $0 show port_forward_service app2 sandbox nginx 80 9120"
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

CMD_SCRIPT="$SCRIPTS_DIR/$CMD.sh"

if [ -x "$CMD_SCRIPT" ]; then
  echo "Running: $CMD"
  "$CMD_SCRIPT" "$@"
else
  echo "ERROR: Unknown or non-executable command script: $CMD"
  usage
fi
