#!/bin/bash

# 설정 파일 경로 확인 및 로드
CONFIG_FILE="$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "%-8s%-80s\n" "[ERROR]" "Configuration file '$CONFIG_FILE' not found. Exiting..."
    exit 1
fi
source "$CONFIG_FILE"

mkdir -p ${CONFIG_DIR}/orig
AGENT_CONFIG_FILE="${CONFIG_DIR}/orig/agent-config.yaml"

# 1. 파일 초기화 및 헤더 작성
cat > "${AGENT_CONFIG_FILE}" << EOF
apiVersion: v1beta1
kind: AgentConfig
rendezvousIP: ${RENDEZVOUS_IP}
additionalNTPSources:
$(for ntp in "${NTP_SERVERS[@]}"; do echo "  - $ntp"; done)
hosts:
EOF

# 2. 노드 리스트 순회하며 호스트 설정 추가
for node in "${NODE_INFO_LIST[@]}" 
do
# awk를 사용하여 안전하게 필드 분리 (구분자 --)
    role=$(echo "$node" | awk -F'--' '{print $1}')
    hostname=$(echo "$node" | awk -F'--' '{print $2}')
    interface=$(echo "$node" | awk -F'--' '{print $3}')
    mac=$(echo "$node" | awk -F'--' '{print $4}')
    ip_address=$(echo "$node" | awk -F'--' '{print $5}')
    prefix=$(echo "$node" | awk -F'--' '{print $6}')
    gateway=$(echo "$node" | awk -F'--' '{print $7}')
    tableid=$(echo "$node" | awk -F'--' '{print $8}')

cat >> "$AGENT_CONFIG_FILE" << EOF
  - hostname: ${hostname}
    role: ${role}
    interfaces:
      - name: ${interface}
        macAddress: ${mac}
    networkConfig:
      interfaces:
        - name: ${interface}
          type: ethernet
          state: up
          mac-address: ${mac}
          ipv4:
            enabled: true
            address:
              - ip: ${ip_address}
                prefix-length: ${prefix}
            dhcp: false
      dns-resolver:
        config:
          server:
$(for dns in "${DNS_SERVERS[@]}"; do echo "            - $dns"; done)
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: ${gateway}
            next-hop-interface: ${interface}
            table-id: ${tableid}
EOF
done

echo "Success: $AGENT_CONFIG_FILE has been generated."