#!/bin/sh

CONFIG_FILE="$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "%-8s%-80s\n" "[ERROR]" "Configuration file '$CONFIG_FILE' not found. Exiting..."
    exit 1
fi
source "$CONFIG_FILE"

AGENT_CONFIG_DIR="${CONFIG_DIR}/orig/agent-config.yaml"

cat > "$AGENT_CONFIG_DIR" << EOF
apiVersion: v2alpha1
kind: AgentConfig
additionalNTPSources:
    ${NTP_SERVERS[@]}
rendezvousIP: ${RENDEZVOUS_IP}
hosts:
EOF

for node in "${NODE_INFO_LIST[@]}" 
do
    IFS='--' read -r role hostname interface_name mac_address ip_address prefix_length gateway_ip <<< "$node"
cat >> "$AGENT_CONFIG_DIR" << EOF
  - hostname: ${hostname}
    role: ${role}
    interfaces:
      - name: ${interface_name}
        macAddress: ${mac_address}
    networkConfig: 
        interfaces: 
          - name: ${interface_name}
            type: ethernet 
            state: up
            mac-address: ${mac_address}
            ipv4:
                address:
                  - ip: ${ip_address}
                    prefix-length: ${prefix_length} 
                dhcp: false
                enabled: true
        dns-resolver:
            config:
            server:
                ${DNS_SERVERS[@]}
        routes:
            config:
              - destination: 0.0.0.0/0
                next-hop-address: ${gateway_ip}
                next-hop-interface: ${interface_name}
                table-id: 254
EOF
done