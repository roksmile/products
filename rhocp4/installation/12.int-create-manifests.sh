#!/bin/bash

# 00.ocp-nodes-info.sh 로드 (변수 활용을 위함)
source "$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"

ORIG_DIR="${CONFIG_DIR}/orig"
TARGET_DIR="${CONFIG_DIR}"

mkdir -p $ORIG_DIR/openshift

# 1. 파일 존재 여부 확인 (개선된 문법)
if [[ -f "${ORIG_DIR}/install-config.yaml" && -f "${ORIG_DIR}/agent-config.yaml" ]]; then
    echo "[INFO] 설정 파일이 확인되었습니다. 파일을 ${TARGET_DIR}로 복사합니다."
    
    # 파일 복사
    cp ${ORIG_DIR}/install-config.yaml ${TARGET_DIR}/
    cp ${ORIG_DIR}/agent-config.yaml ${TARGET_DIR}/
    cp ${TARGET_DIR}/openshift/*.yaml ${ORIG_DIR}/openshift/
    
    echo "[INFO] 파일 복사 완료. OpenShift 클러스터 매니페스트 생성을 시작합니다."
    
    # 2. OpenShift 매니페스트 생성 명령어 실행
    openshift-install agent create cluster-manifests --dir "${TARGET_DIR}"
    
    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------------"
        echo "[SUCCESS] 매니페스트 생성이 완료되었습니다."
        echo "결과물 확인: ls -l ${TARGET_DIR}/cluster-manifests"
        echo "--------------------------------------------------------"
    else
        echo "[ERROR] 매니페스트 생성 중 오류가 발생했습니다."
        exit 1
    fi
else
    echo "[ERROR] ${ORIG_DIR} 내에 install-config.yaml 또는 agent-config.yaml 파일이 없습니다."
    echo "파일 생성이 먼저 완료되었는지 확인해 주세요."
    exit 1
fi