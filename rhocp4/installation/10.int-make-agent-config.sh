#!/bin/bash

# 설정 파일 경로 확인 및 로드
CONFIG_FILE="$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "%-8s%-80s\n" "[ERROR]" "Configuration file '$CONFIG_FILE' not found. Exiting..."
    exit 1
fi
source "$CONFIG_FILE"

AGENT_CONFIG_FILE="${CONFIG_DIR}/orig/agent-config.yaml"

# 1. 파일 초기화 및 헤더 작성
cat > "${AGENT_CONFIG_FILE}" << EOF
apiVersion: v1beta1
kind: AgentConfig
metadata:
  name: ${CLUSTER_NAME}
additionalNTPSources:
$(for ntp in "${NTP_SERVERS[@]}"; do echo "  - $ntp"; done)
rendezvousIP: ${RENDEZVOUS_IP}
hosts:
EOF

# 2. 노드 리스트 순회하며 호스트 설정 추가
for node in "${NODE_INFO_LIST[@]}" 
do
    # 00.ocp-nodes-info.sh의 형식: role--hostname--interface--mac--ip--prefix--dns--gateway
    IFS='--' read -r role hostname interface mac ip_address prefix gateway tableid <<< "$node"

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
            ${DNS_SERVER}
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: ${gateway}
            next-hop-interface: ${interface}
            table-id: ${tableid}
EOF
done

echo "Success: $AGENT_CONFIG_FILE has been generated."