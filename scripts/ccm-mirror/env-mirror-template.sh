#!/usr/bin/env bash
# Env for CyberArk Certificate Manager Charts and Images mirroring. 

# ---- Source component versions from local file (self-contained) ----
[ -f "./component-versions.sh" ] && . "./component-versions.sh"

# --- Source registries (CyberArk Certificate Manager) ---
# Leave user/pass empty if your tenant allows pull with token-less access for charts/images.
export SRC_USERNAME="${SRC_USERNAME:-REPLACE_WITH_SOURCE_REG_USER}"
export SRC_PASSWORD="${SRC_PASSWORD:-REPLACE_WITH_SOURCE_REG_PASSWORD}"

# ---- Platform selection for images ----
# Default: copy linux/amd64 from a multi-arch manifest list
export PLATFORM="${PLATFORM:-linux/amd64}"
# Set COPY_ALL_PLATFORMS=1 to copy every arch in the list instead of selecting PLATFORM
export COPY_ALL_PLATFORMS="${COPY_ALL_PLATFORMS:-0}"


# --- Destination (Harbor) ---
export DST_REGISTRY="${DST_REGISTRY:-REPLACE_WITH_DESTINATION_REG_HOST}"
export DST_PROJECT="${DST_PROJECT:-my-mirror}" #REPLACE_WITH_DESTINATION_REG_PROJECT
export DST_USERNAME="${DST_USERNAME:-robot\$my-mirror-ci}"   # escape $ if editing inline like hello\$123
export DST_PASSWORD="${DST_PASSWORD:-REPLACE_WITH_DESTINATION_REG_PASSWORD}"

# --- Behavior ---
export MODE="${MODE:-mirror}"                               # mirror | download | upload
export INSECURE="${INSECURE:-0}"                            # 1 = skip TLS verify (test only)
export WORKDIR="${WORKDIR:-$HOME/tmp/cyberark-cm-mirror1}"        # for download/upload tarballs
export SOURCE_LIST="${SOURCE_LIST:-./charts.txt}"           # the list with ${VARS}

# ---- Idempotency / retries ----
# Skip download if file already exists (default: 1). Set to 0 to force re-download.
export DOWNLOAD_SKIP_EXISTING="${DOWNLOAD_SKIP_EXISTING:-1}"
# If not skipping, and file exists, remove and re-download when set to 1 (default: 0).
export DOWNLOAD_OVERWRITE="${DOWNLOAD_OVERWRITE:-0}"
# Retries for skopeo copy operations
export SKOPEO_RETRIES="${SKOPEO_RETRIES:-3}"
