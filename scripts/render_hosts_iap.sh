#!/usr/bin/env bash
# Render host.runtime.yml with the correct IAP ProxyJump for OS Login
# Usage: render_hosts_iap.sh <instance> <project> <zone> [os_login_user]
 
set -euo pipefail
INSTANCE_NAME="${1:?instance name}"
PROJECT="${2:?project id}"
ZONE="${3:?zone}"
USER="${4:-}" # optional: service-account/user email for OS Login
 
#Ask gcloud what SSH command it would use via IAP (no connection made)
DRYRUN=$(gcloud compute ssh "${INSTANCE_NAME}" \
    --project "${PROJECT}" \
    --zone "${ZONE}" \
    --tunnel-through-iap \
    ${USER:+-- -l "${USER}"} \
    --dry-run 2>/dev/null || true)
 
# Extract ProxyJump (-J ....) chain
JUMP=$(sed -n 's/.* -J \(.*\)$/\1/p' <<<"$DRYRUN")
 
# Emit runtime inventory for Ansible
cat <<EOF
all:
    children:
        targets:
            hosts:
                ${INSTANCE_NAME}:
                    ansible_host: ${INSTANCE_NAME}
                    ansible_user: ${USER:-}
                    ansible_ssh_common_args: >-
                        -o StrictHostKeyChecking=no
                        -o UserKnownHostsFile=/dev/null
                        ${JUMP:+-J ${JUMP}}
EOF