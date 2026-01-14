#!/bin/bash

# 1. 환경 설정
ISO_PATH="/data/iso/kscada-v4.20.4_agent.x86_64.iso"
DISK_BASE_DIR="/data/vms"
BRIDGE_NAME="hostbr0" 
OS_VARIANT="rhel9.4" # RHEL 9.7 용

# 2. 필수 환경 체크 (Validation)
echo "사전 환경 체크 중..."

# ISO 파일 존재 여부 확인
if [ ! -f "$ISO_PATH" ]; then
    echo "[ERROR] ISO 파일이 존재하지 않습니다: $ISO_PATH" >&2
    exit 1
fi

# 디스크 디렉토리 존재 여부 확인
if [ ! -d "$DISK_BASE_DIR" ]; then
    echo "[ERROR] 디스크 저장 디렉토리가 존재하지 않습니다: $DISK_BASE_DIR" >&2
    exit 1
fi

# 네트워크 브릿지 존재 여부 확인 (ip link 명령 사용)
if ! ip link show "$BRIDGE_NAME" > /dev/null 2>&1; then
    echo "[ERROR] 네트워크 브릿지가 시스템에 존재하지 않습니다: $BRIDGE_NAME" >&2
    exit 1
fi

echo "체크 완료: 모든 환경이 정상입니다."

# 3. 대상 VM 리스트
VM_DATA_LIST=(
    "kscada.mst01-8-32-120-1-[52:54:00:d7:7c:11,]"
    "kscada.mst02-8-32-120-1-[52:54:00:d7:7c:12,]"
    "kscada.mst03-8-32-120-1-[52:54:00:d7:7c:13,]"    
)

# 4. 생성 로직
for DATA in "${VM_DATA_LIST[@]}"; do
    echo "===================================================="
    
    # 데이터 파싱
    VM_NAME=$(echo $DATA | cut -d'-' -f1)
    VCPUS=$(echo $DATA | cut -d'-' -f2)
    RAM_GB=$(echo $DATA | cut -d'-' -f3)
    RAM_MB=$((RAM_GB * 1024))
    DISK_SIZE=$(echo $DATA | cut -d'-' -f4)
    NIC_COUNT=$(echo $DATA | cut -d'-' -f5)
    
    MAC_RAW=$(echo $DATA | grep -oP '\[\K[^\]]+')
    IFS=',' read -r -a MAC_ARRAY <<< "$MAC_RAW"

    DISK_PATH="${DISK_BASE_DIR}/${VM_NAME}_os.qcow2"

    # 네트워크 옵션 빌드
    NET_OPTIONS=""
    for ((i=0; i<NIC_COUNT; i++)); do
        CURRENT_MAC="${MAC_ARRAY[$i]}"
        if [ -n "$CURRENT_MAC" ]; then
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio,mac=$CURRENT_MAC"
        else
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio"
        fi
    done

    # 디스크 이미지 생성
    if [ ! -f "$DISK_PATH" ]; then
        qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE}G"
    fi

    # VM 정의 (시작하지 않음)
    echo "VM $VM_NAME 정의 중..."
    
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
