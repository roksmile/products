#!/bin/bash

# 00.ocp-nodes-info.sh 로드
source "$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"

TARGET_DIR="${CONFIG_DIR}"
export XDG_CACHE_HOME="$PWD/cache"

# 1. 이전 단계(매니페스트 생성) 완료 여부 확인
if [[ ! -d "${TARGET_DIR}/cluster-manifests" ]]; then
    echo "[ERROR] 매니페스트 디렉토리가 없습니다. 먼저 cluster-manifests를 생성해야 합니다."
    exit 1
fi

echo "[INFO] OpenShift Agent Discovery ISO 이미지 생성을 시작합니다."
echo "[INFO] 이 작업은 시간이 다소 소요될 수 있습니다 (네트워크 상태 및 자원에 따라 다름)."

# 2. ISO 이미지 생성 명령어 실행
# --dir 옵션으로 지정된 디렉토리의 agent-config.yaml 등을 참조하여 agent.iso를 생성합니다.
openshift-install agent create image --dir "${TARGET_DIR}"

# 3. 결과 확인
if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "[SUCCESS] ISO 이미지 생성이 완료되었습니다."
    
    # 생성된 파일 확인 (보통 agent.iso라는 이름으로 생성됨)
    if [ -f "${TARGET_DIR}/agent.x86_64.iso" ]; then
        echo "생성된 이미지 위치: ${TARGET_DIR}/agent.x86_64.iso"
        ls -lh "${TARGET_DIR}/agent.x86_64.iso"
    fi
    echo "--------------------------------------------------------"
    echo "이제 이 ISO 파일을 각 노드(Master/Worker)에 마운트하여 부팅하세요."
else
    echo "[ERROR] ISO 이미지 생성 중 오류가 발생했습니다."
    exit 1
fi