#!/usr/bin/env bash
# Print the full OCI chart references (dest registry) after mirror/upload.
# Usage: ./list-charts.sh [--md] [--out FILE]
#   --md       : emit Markdown table
#   --out FILE : also write output to FILE
#
# Optional: ORAS can be used to verify what’s actually in the registry.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# load env (DST_REGISTRY/DST_PROJECT) and versions
[ -f "${SCRIPT_DIR}/env-mirror.sh" ] && . "${SCRIPT_DIR}/env-mirror.sh"
[ -f "${SCRIPT_DIR}/component-versions.sh" ] && . "${SCRIPT_DIR}/component-versions.sh"

: "${DST_REGISTRY:?DST_REGISTRY is required}"
: "${DST_PROJECT:?DST_PROJECT is required}"

CHARTS_FILE="${SOURCE_LIST:-${SCRIPT_DIR}/charts.txt}"
MODE_MD=0
OUTFILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --md) MODE_MD=1; shift ;;
    --out) OUTFILE="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

expand_vars(){ eval "echo \"$1\""; }

# collect lines
out=""
if [ $MODE_MD -eq 1 ]; then
  out+="| Chart | Version | Destination OCI Reference |\n"
  out+="|-------|---------|-----------------------------|\n"
fi

while IFS= read -r raw; do
  line="$(expand_vars "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  if printf '%s' "$line" | grep -q '^oci://'; then
    ver="${line##*:}"
    repo="${line%:${ver}}"
    name="${repo##*/}"
    dst="oci://${DST_REGISTRY}/${DST_PROJECT}/charts/${name}:${ver}"
    if [ $MODE_MD -eq 1 ]; then
      out+="| ${name} | ${ver} | \`${dst}\` |\n"
    else
      out+="${dst}\n"
    fi
  fi
done < "${CHARTS_FILE}"

# output list/table
printf "%b" "$out"
[ -n "$OUTFILE" ] && printf "%b" "$out" > "$OUTFILE"

echo
echo "To verify with ORAS (example for cert-manager):"
echo "  oras repo tags ${DST_REGISTRY}/${DST_PROJECT}/charts/cert-manager"
