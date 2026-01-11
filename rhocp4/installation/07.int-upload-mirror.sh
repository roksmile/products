#!/bin/bash

# 색상 정의 (출력 가독성을 위함)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # 색상 초기화

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}   OpenShift Mirroring Script (v2)        ${NC}"
echo -e "${BLUE}==========================================${NC}"

# 실행할 함수 정의
run_ocp() {
    echo -e "${YELLOW}>>> [1/3] OCP Mirroring 시작...${NC}"
    oc-mirror --v2 --dest-tls-verify=false --config ocp/ocp-isc.yaml --from file://$PWD/ocp docker://nexus.rok.lab:5000/ocp4 --cache-dir ./cache
}

run_olm_redhat() {
    echo -e "${YELLOW}>>> [2/3] OLM RedHat Mirroring 시작...${NC}"
    oc-mirror --v2 --dest-tls-verify=false --config olm-redhat/olm-redhat.yaml --from file://$PWD/olm-redhat docker://nexus.rok.lab:5000/olm-redhat --cache-dir ./cache
}

run_olm_certified() {
    echo -e "${YELLOW}>>> [3/3] OLM Certified Mirroring 시작...${NC}"
    oc-mirror --v2 --dest-tls-verify=false --config olm-certified/olm-certified-isc.yaml --from file://$PWD/olm-certified docker://nexus.rok.lab:5000/olm-certified --cache-dir ./cache
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
        echo "잘못된 입력입니다. 스크립트를 다시 실행해주세요."
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}------------------------------------------${NC}"
    echo -e "${GREEN} 모든 작업이 성공적으로 완료되었습니다.${NC}"
    echo -e "${GREEN}------------------------------------------${NC}"
else
    echo -e "\033[0;31m 오류가 발생했습니다. 로그를 확인하세요.\033[0m"
fi