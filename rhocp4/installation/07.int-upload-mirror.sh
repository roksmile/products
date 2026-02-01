#!/bin/bash

echo -e "=========================================="
echo -e "    OpenShift Mirroring Script (v2)       "
echo -e "=========================================="

# 1. 이미지 레지스트리 정보 입력 받기
echo -e "[Registry 설정]"
read -p "컨테이너 이미지 레지스트리 주소를 입력하세요 (기본값: nexus.kdneri.com:5000): " TARGET_REGISTRY
TARGET_REGISTRY=${TARGET_REGISTRY:-nexus.kdneri.com:5000}

echo -e ">> 목적지 레지스트리: $TARGET_REGISTRY\n"

# 실행할 함수 정의 (변수 사용)
run_ocp() {
    echo -e ">>> [1/3] OCP Mirroring 시작..."
    oc-mirror --v2 --dest-tls-verify=false \
        --config ocp/ocp-isc.yaml \
        --from file://$PWD/ocp \
        docker://$TARGET_REGISTRY/ocp4 \
        --cache-dir ./cache
}

run_olm_redhat() {
    echo -e "$>>> [2/3] OLM RedHat Mirroring 시작..."
    oc-mirror --v2 --dest-tls-verify=false \
        --config olm-redhat/olm-redhat-isc.yaml \
        --from file://$PWD/olm-redhat \
        docker://$TARGET_REGISTRY/olm-redhat \
        --cache-dir ./cache
}

run_olm_certified() {
    echo -e ">>> [3/3] OLM Certified Mirroring 시작..."
    oc-mirror --v2 --dest-tls-verify=false \
        --config olm-certified/olm-certified-isc.yaml \
        --from file://$PWD/olm-certified \
        docker://$TARGET_REGISTRY/olm-certified \
        --cache-dir ./cache
}

# 메뉴 출력
echo "실행할 작업을 선택하세요:"
echo "1) OCP Mirroring"
echo "2) OLM RedHat Mirroring"
echo "3) OLM Certified Mirroring"
echo "4) All (1, 2, 3 모두 실행)"
echo "q) 종료 (Quit)"
echo -n "선택 (1-4/q): "
read choice

case $choice in
    1)
        run_ocp
        ;;
    2)
        run_olm_redhat
        ;;
    3)
        run_olm_certified
        ;;
    4)
        run_ocp
        run_olm_redhat
        run_olm_certified
        ;;
    q|Q)
        echo "종료합니다."
        exit 0
        ;;
    *)
        echo -e "잘못된 입력입니다. 스크립트를 다시 실행해주세요."
        exit 1
        ;;
esac

# 성공 여부 체크
if [ $? -eq 0 ]; then
    echo -e "------------------------------------------"
    echo -e " 모든 작업이 성공적으로 완료되었습니다."
    echo -e " 대상: $TARGET_REGISTRY"
    echo -e "------------------------------------------"
else
    echo -e "오류가 발생했습니다. 로그를 확인하세요."
fi