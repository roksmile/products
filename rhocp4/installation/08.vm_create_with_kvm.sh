#!/bin/bash

# 1. 환경 설정
ISO_PATH="/data/iso/agent_3.2.iso"
DISK_BASE_DIR="/data/vm"
BRIDGE_NAME="virbr0" 
OS_VARIANT="rhel9.4" # RHEL 9.7 용

# 2. 대상 VM 리스트 (데이터 포맷: 이름-CPU-RAM-DISK-NIC개수-[MAC1,MAC2,...])
VM_DATA_LIST=(
    "kscada.mst01-8-32-120-1-[52:54:00:d7:7c:11,]"
    "kscada.mst02-8-32-120-1-[52:54:00:d7:7c:12,]" # NIC 2개, MAC 1개만 지정된 케이스 예시
    "kscada.mst03-8-32-120-1-[52:54:00:d7:7c:13,]" # NIC 2개, MAC 1개만 지정된 케이스 예시    
)

for DATA in "${VM_DATA_LIST[@]}"; do
    echo "===================================================="
    
    # 3. 데이터 파싱
    VM_NAME=$(echo $DATA | cut -d'-' -f1)
    VCPUS=$(echo $DATA | cut -d'-' -f2)
    RAM_GB=$(echo $DATA | cut -d'-' -f3)
    RAM_MB=$((RAM_GB * 1024))
    DISK_SIZE=$(echo $DATA | cut -d'-' -f4)
    NIC_COUNT=$(echo $DATA | cut -d'-' -f5)
    
    MAC_RAW=$(echo $DATA | grep -oP '\[\K[^\]]+')
    IFS=',' read -r -a MAC_ARRAY <<< "$MAC_RAW"

    DISK_PATH="${DISK_BASE_DIR}/${VM_NAME}_os.qcow2"

    # 4. 네트워크 옵션 빌드
    NET_OPTIONS=""
    for ((i=0; i<NIC_COUNT; i++)); do
        CURRENT_MAC="${MAC_ARRAY[$i]}"
        if [ -n "$CURRENT_MAC" ]; then
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio,mac=$CURRENT_MAC"
        else
            NET_OPTIONS="$NET_OPTIONS --network bridge=$BRIDGE_NAME,model=virtio"
        fi
    done

    # 5. 디스크 이미지 생성 (XML 추출을 위해서도 디스크는 존재해야 함)
    if [ ! -f "$DISK_PATH" ]; then
        mkdir -p "$DISK_BASE_DIR"
        qemu-img create -f qcow2 "$DISK_PATH" "${DISK_SIZE}G"
    fi

    # 6. VM 정의 (시작하지 않음)
    # --print-xml: 실제로 생성하지 않고 XML 설정만 출력
    # --dry-run: 실제 리소스를 할당하지 않고 시뮬레이션
    echo "VM $VM_NAME 정의 중 (시작 안 함)..."
    
    virt-install \
        --name "$VM_NAME" \
        --vcpus "$VCPUS" \
        --memory "$RAM_MB" \
        --disk path="$DISK_PATH",bus=virtio \
        $NET_OPTIONS \
        --cdrom "$ISO_PATH" \
        --os-variant "$OS_VARIANT" \
        --graphics vnc \
        --boot hd,cdrom \
        --print-xml --dry-run > "/tmp/${VM_NAME}.xml"

    # 생성된 XML을 사용하여 virsh에 등록 (Define)
    virsh define "/tmp/${VM_NAME}.xml"
    
    if [ $? -eq 0 ]; then
        echo "VM $VM_NAME 가 성공적으로 정의되었습니다. (현재 상태: shut off)"
    else
        echo "VM $VM_NAME 정의 실패."
    fi

    # 임시 XML 파일 삭제
    rm "/tmp/${VM_NAME}.xml"
done
