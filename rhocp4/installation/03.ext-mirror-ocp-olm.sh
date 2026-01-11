#!/bin/bash

# 1. 환경 변수 기본 설정
PULL_SECRET="pull-secret.txt"
DEFAULT_CACHE_DIR="./cache"

echo "========================================"
echo "   OpenShift oc-mirror 자동화 스크립트"
echo "========================================"

# 2. 미러링 대상 선택 받기
echo "미러링할 항목을 선택하세요:"
echo "1) ocp"
echo "2) redhat (olm-redhat)"
echo "3) certified (olm-certified)"
read -p "선택 (1/2/3 또는 이름 입력): " SELECTION

case $SELECTION in
    1|ocp)
        TARGET_NAME="ocp"
        ISC_FILE="ocp/ocp-isc.yaml"
        DEFAULT_DESTINATION="./ocp"
        ;;
    2|redhat)
        TARGET_NAME="olm-redhat"
        ISC_FILE="olm-redhat/olm-redhat-isc.yaml" # 파일명이 다를 경우 수정하세요
        DEFAULT_DESTINATION="./olm-redhat"
        ;;
    3|certified)
        TARGET_NAME="olm-certified"
        ISC_FILE="olm-certified/olm-certified-isc.yaml" # 파일명이 다를 경우 수정하세요
        DEFAULT_DESTINATION="./olm-certified"
        ;;
    *)
        echo "[오류] 잘못된 선택입니다. 스크립트를 종료합니다."
        exit 1
        ;;
esac

echo "----------------------------------------"
echo "선택된 대상: $TARGET_NAME"

# 3. Pull Secret 파일 존재 여부 확인
if [ ! -f "$PULL_SECRET" ]; then
    echo "[오류] $PULL_SECRET 파일을 찾을 수 없습니다."
    echo "https://console.redhat.com/openshift/downloads 에서 다운 받으세요."
    exit 1
fi

# 4. 구성 파일(YAML) 존재 여부 확인
if [ ! -f "$ISC_FILE" ]; then
    echo "[오류] 설정 파일($ISC_FILE)을 찾을 수 없습니다."
    echo "해당 디렉토리에 YAML 파일이 있는지 확인해 주세요."
    exit 1
fi

# 5. 캐시 디렉토리 및 목적지 입력 받기
read -p "캐시 디렉토리 경로 (기본값: $DEFAULT_CACHE_DIR): " USER_CACHE_DIR
CACHE_DIR=${USER_CACHE_DIR:-$DEFAULT_CACHE_DIR}

read -p "Destination (기본값: $DEFAULT_DESTINATION): " USER_DESTINATION
DESTINATION=${USER_DESTINATION:-$DEFAULT_DESTINATION}

# 6. oc-mirror 실행
echo "----------------------------------------"
echo "미러링을 시작합니다..."
echo "설정 파일: $ISC_FILE"
echo "캐시 경로: $CACHE_DIR"
echo "대상 경로: $DESTINATION"
echo "----------------------------------------"

oc-mirror --v2 \
  --authfile "$PULL_SECRET" \
  --log-level info \
  --cache-dir "$CACHE_DIR" \
  --config "$ISC_FILE" \
  "file://$DESTINATION"

# 실행 결과 확인
if [ $? -eq 0 ]; then
    echo "----------------------------------------"
    echo "[성공] $TARGET_NAME 미러링 작업이 완료되었습니다."
else
    echo "----------------------------------------"
    echo "[실패] oc-mirror 실행 중 오류가 발생했습니다."
    exit 1
fi