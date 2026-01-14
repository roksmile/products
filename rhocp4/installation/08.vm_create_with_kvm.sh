#!/bin/bash

# 1. 환경 설정
ISO_PATH="/data/iso/agent_3.2.iso"
DISK_BASE_DIR="/data/vm"
BRIDGE_NAME="virbr0" 
OS_VARIANT="rhel9.4" # RHEL 9.7 용

# 2. 대상 VM 리스트 (데이터 포맷: 이름-CPU-RAM-DISK-NIC개수-[MAC1,MAC2,...])
VM_DATA_LIST=(
    "mst01-8-32-120-1-[52:54:00:d7:7c:11,]"
    "mst02-8-32-120-1-[52:54:00:d7:7c:12,]" # NIC 2개, MAC 1개만 지정된 케이스 예시
    "mst03-8-32-120-1-[52:54:00:d7:7c:13,]" # NIC 2개, MAC 1개만 지정된 케이스 예시    
)

for DATA in "${VM_DATA_LIST[@]}"; do
    echo "===================================================="
    
    # 3. 기본 데이터 파싱
    VM_NAME=$(echo $DATA | cut -d'-' -f1)
    VCPUS=$(echo $DATA | cut -d'-' -f2)
    RAM_GB=$(echo $DATA | cut -d'-' -f3)
    RAM_MB=$((RAM_GB * 1024))
    DISK_SIZE=$(echo $DATA | cut -d'-' -f4)
    NIC_COUNT=$(echo $DATA | cut -d'-' -f5)
    
    # MAC 주소 배열 추출 (대괄호 제거 후 콤마로 분리)
    MAC_RAW=$(echo $DATA | grep -oP '\[\K[^\]]+')
    IFS=',' read -r -a MAC_ARRAY <<< "$MAC_RAW"

    DISK_PATH="${DISK_BASE_DIR}/${VM_NAME}_os.qcow2"

    # 4. 네트워크 옵션 동적 생성
    NET_OPTIONS=""
    for ((i=0; i<NIC_COUNT; i++)); do
        # 해당 인덱스에 MAC 주소가 있는지 확인 (공백 제외)
        CURRENT_MAC="${MAC_ARRAY[$i]}"
        
        if [ -n "$CURRENT_MAC" ]; then
            echo "NIC $((i+1)): 지정된 MAC 사용 ($CURRENT_MAC)"
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio,mac=$CURRENT_MAC"
        else
            echo "NIC $((i+1)): 시스템 자동 생성 MAC 사용"
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio"
        fi
    done

    # 5. 디스크 이미지 생성
    if [ ! -f "$DISK_PATH" ]; then
        mkdir -p "$DISK_BASE_DIR"
        qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE}G"
    fi

    # 6. VM 생성 실행
    virt-install \
        --name "$VM_NAME" \
        --vcpus "$VCPUS" \
        --memory "$RAM_MB" \
        --disk path="$DISK_PATH",bus=virtio \
        $NET_OPTIONS \
        --cdrom "$ISO_PATH" \
        --os-variant "$OS_VARIANT" \
        --graphics vnc \
        --noautoconsole \
        --boot hd,cdrom
        
    echo "VM $VM_NAME 생성 시도가 완료되었습니다."
done
