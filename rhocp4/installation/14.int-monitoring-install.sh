#!/bin/bash

# 00.ocp-nodes-info.sh 로드 (변수 활용)
source "$(dirname "$(realpath "$0")")/00.ocp-nodes-info.sh"

TARGET_DIR="${CONFIG_DIR}"

# 1. 대상 디렉토리 존재 확인
if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "[ERROR] 설치 디렉토리(${TARGET_DIR})가 존재하지 않습니다."
    exit 1
fi

echo "========================================================"
echo " OpenShift Agent 설치 모니터링을 시작합니다."
echo " 디렉토리: ${TARGET_DIR}"
echo "========================================================"

# 2. 랑데부(Rendezvous) 노드 통신 확인 안내
echo "[STEP 1] 모든 노드를 ISO로 부팅하세요."
echo "Rendezvous IP: ${RENDEZVOUS_IP}로 노드들이 모이기 시작합니다."
echo "--------------------------------------------------------"

# 3. Bootstrap 단계 모니터링
# 노드들이 기본 OS를 설치하고 클러스터 제어판(Control Plane)을 형성하는 과정입니다.
echo "[INFO] Bootstrap 완료를 기다리는 중... (약 20~40분 소요)"
openshift-install agent wait-for bootstrap-complete --dir "${TARGET_DIR}" --log-level info

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "[SUCCESS] Bootstrap 단계가 완료되었습니다!"
    echo "이제 Kubeconfig를 사용하여 클러스터에 접근할 수 있습니다."
    echo "Export 경로: export KUBECONFIG=${TARGET_DIR}/auth/kubeconfig"
    echo "--------------------------------------------------------"
else
    echo "[ERROR] Bootstrap 과정 중 시간이 초과되었거나 오류가 발생했습니다."
    exit 1
fi

# 4. 최종 설치 완료 모니터링
# 모든 연산자(Operators)가 정상 상태가 되고 설치가 최종 마무리되는 과정입니다.
echo "[INFO] 최종 설치 완료를 기다리는 중... (추가 시간 소요)"
openshift-install agent wait-for install-complete --dir "${TARGET_DIR}" --log-level info

if [ $? -eq 0 ]; then
    echo "========================================================"
    echo " [CONGRATULATIONS] OpenShift 클러스터 설치가 완료되었습니다!"
    echo "kubeadmin password : " $(cat ${target_dir}/auth/kubeadmin-password) 
    echo "========================================================"
else
    echo "[ERROR] 최종 설치 확인 중 오류가 발생했습니다."
    exit 1
fi