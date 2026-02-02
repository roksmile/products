#!/bin/bash

# 0. 환경 설정 로드
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
if [ -f "${SCRIPT_DIR}/00.ocp-nodes-info.sh" ]; then
    source "${SCRIPT_DIR}/00.ocp-nodes-info.sh"
else
    echo "[ERROR] 00.ocp-nodes-info.sh 파일을 찾을 수 없습니다."
    exit 1
fi

TARGET_DIR="${CONFIG_DIR:-./config}"
ISO_NAME="nodes.x86_64.iso"
PULL_SECRET_FILE="pull-secret-tmp.json"

# 보안을 위해 스크립트 종료 시 임시 Pull Secret 삭제
trap 'rm -f "${PULL_SECRET_FILE}"' EXIT SIGINT SIGTERM

echo "### [STEP 1] 사전 준비 확인 ###"

# 1-1. oc 커맨드 체크
if ! command -v oc &> /dev/null; then
    echo "[ERROR] 'oc' 커맨드를 찾을 수 없습니다. OpenShift CLI를 설치해주세요."
    exit 1
fi

# 1-2. 설정 파일 복사
if [ -f "${TARGET_DIR}/add-nodes/nodes-config.yaml" ]; then
    cp "${TARGET_DIR}/add-nodes/nodes-config.yaml" "${TARGET_DIR}/nodes-config.yaml"
    echo "[INFO] nodes-config.yaml 복사 완료."
else
    echo "[ERROR] ${TARGET_DIR}/add-nodes/nodes-config.yaml 파일이 없습니다."
    exit 1
fi

# 1-3. Pull Secret 추출
echo "[INFO] 클러스터에서 Pull Secret을 추출합니다..."
if ! oc -n openshift-config get secret pull-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > "${PULL_SECRET_FILE}"; then
    echo "[ERROR] Pull Secret 추출 실패. 'oc login' 상태를 확인하세요."
    exit 1
fi

echo "---"
echo "### [STEP 2] ISO 이미지 생성 시작 ###"
echo "[WAIT] 이미지 생성 중입니다. 이 작업은 시간이 다소 소요될 수 있습니다..."

# 2. ISO 이미지 생성 실행
if oc adm node-image create --dir="${TARGET_DIR}" -a "${PULL_SECRET_FILE}" -o "${ISO_NAME}"; then
    echo "--------------------------------------------------------"
    echo "[SUCCESS] ISO 이미지 생성이 완료되었습니다."
    
    RESULT_PATH="${TARGET_DIR}/${ISO_NAME}"
    if [ -f "${RESULT_PATH}" ]; then
        echo "생성된 이미지 위치: ${RESULT_PATH}"
        ls -lh "${RESULT_PATH}"
    fi
    echo "--------------------------------------------------------"
    echo "가이드: 이제 이 ISO 파일을 각 노드에 마운트하여 부팅하세요."
else
    echo "--------------------------------------------------------"
    echo "[ERROR] ISO 이미지 생성 중 오류가 발생했습니다."
    echo "로그를 확인하여 nodes-config.yaml의 구문을 점검하세요."
    exit 1
fi