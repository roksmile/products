#!/bin/sh

CONFIG_FILE="$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "%-8s%-80s\n" "[ERROR]" "Configuration file '$CONFIG_FILE' not found. Exiting..."
    exit 1
fi
source "$CONFIG_FILE"

mkdir -p "${CONFIG_DIR}/{orig,openshift}"

# install-config.yaml 생성
INSTALL_CONFIG_PATH="${CONFIG_DIR}/orig/install-config.yaml"
cat > "$INSTALL_CONFIG_PATH" << EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  replicas: ${WORKER_COUNT} 
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: ${MASTER_COUNT}
metadata:
  name: ${CLUSTER_NAME}
networking:
  networkType: OVNKubernetes
  machineNetwork:
  - cidr: ${MACHINE_NETWORK}
  serviceNetwork:
  - ${SERVICE_NETWORK}
  clusterNetwork:
  - cidr: ${CLUSTER_NETWORK}
    hostPrefix: 24
platform:
  none: {}
fips: false
pullSecret: '{
    "auths": {
        "${REGISTRY_ADDRESS}": {
            "auth": \"$(echo -n "${REGISTRY_ADMIN_USER}:${REGISTRY_ADMIN_PWD}" | base64 -w0)]\",
            "email": "rkim@redhat.com"
    }
  }
}'
sshKey: |
    $(for key in "${SSH_KEYS[@]}"; do echo "$key"; done)

additionalTrustBundle: |
    $(cat ./certs/root_ca/rootCA.crt| sed 's/^/    /')
imageDigestSources:
- mirrors:
  - ${REGISTRY_ADDRESS}/ocp4/openshift/release-images
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${REGISTRY_ADDRESS}/ocp4/openshift/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF 