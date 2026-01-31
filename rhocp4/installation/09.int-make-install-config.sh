#!/bin/bash

# 설정 파일 경로 확인 및 로드
CONFIG_FILE="$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "%-8s%-80s\n" "[ERROR]" "Configuration file '$CONFIG_FILE' not found. Exiting..."
    exit 1
fi
source "$CONFIG_FILE"

# 디렉토리 생성
mkdir -p "${CONFIG_DIR}/orig"
mkdir -p "${CONFIG_DIR}/openshift"

# 1. Pull Secret 생성 (base64 인코딩 오류 수정)
# - REGISTRY_ADMIN_USER, REGISTRY_ADMIN_PWD, REGISTRY_ADDRESS 사용
AUTH_BASE64=$(echo -n "${REGISTRY_ADMIN_USER}:${REGISTRY_ADMIN_PWD}" | base64 -w0)

# 2. SSH Keys 및 추가 인증서 처리 (들여쓰기 최적화)
SSH_KEYS_FORMATTED=$(for key in "${SSH_KEYS[@]}"; do echo "- $key"; done)

if [[ ! -f ./certs/root_ca/rootCA.crt ]]; then
    echo "[WARNING] ./certs/root_ca/rootCA.crt 파일이 없습니다. "
    return 1
else
    TRUSTED_CA=$(cat ./certs/root_ca/rootCA.crt 2>/dev/null | sed 's/^/  /')
fi

INSTALL_CONFIG_FILE="${CONFIG_DIR}/orig/install-config.yaml" 
cat > "${INSTALL_CONFIG_FILE}" << EOF
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
pullSecret: '{"auths":{"${REGISTRY_ADDRESS}":{"auth":"${AUTH_BASE64}","email":"rkim@redhat.com"}}}'
sshKey: 
${SSH_KEYS_FORMATTED}
additionalTrustBundle: |
${TRUSTED_CA}
imageDigestSources:
- mirrors:
  - ${REGISTRY_ADDRESS}/ocp4/openshift/release-images
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${REGISTRY_ADDRESS}/ocp4/openshift/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF

echo "Success: Generated $INSTALL_CONFIG_FILE"