#!/bin/bash

# 1. 설치할 버전 입력 받기
echo -n "설치할 OpenShift 버전을 입력하세요 (예: 4.14.35): "
read VERSION

if [ -z "$VERSION" ]; then
    echo "오류: 버전을 입력해야 합니다."
    exit 1
fi

# 2. OS 버전 확인
if [ -f /etc/os-release ]; then
    OS_MAJOR_VERSION=$(grep -oP '(?<=VERSION_ID=")\d+' /etc/os-release)
else
    echo "오류: /etc/os-release 파일을 찾을 수 없습니다."
    exit 1
fi

# 3. 폴더 생성
TARGET_DIR="./tools"
BIN_DIR="/usr/local/bin"
mkdir -p "$TARGET_DIR"

# 4. OS별 변수 및 URL 설정
DOWNLOAD_LIST=(
    "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/butane/latest/butane-amd64"
    "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/openshift-install-linux.tar.gz"
)

if [ "$OS_MAJOR_VERSION" == "9" ]; then
    OPM_FILE="opm-linux-rhel9.tar.gz"
    MIRROR_FILE="oc-mirror.rhel9.tar.gz"
    CLIENT_FILE="openshift-client-linux-amd64-rhel9.tar.gz"
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${OPM_FILE}")
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${CLIENT_FILE}")
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${MIRROR_FILE}")
    
elif [ "$OS_MAJOR_VERSION" == "8" ]; then
    OPM_FILE="opm-linux.tar.gz"
    MIRROR_FILE="oc-mirror.tar.gz"
    CLIENT_FILE="openshift-client-linux-amd64-rhel8.tar.gz"
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${OPM_FILE}")
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${CLIENT_FILE}")
    DOWNLOAD_LIST+=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${VERSION}/${MIRROR_FILE}")
else
    echo "오류: RHEL 8 또는 9만 지원합니다."
    exit 1
fi

# 5. 다운로드 실행
echo "--- 도구 다운로드 중... ---"
for URL in "${DOWNLOAD_LIST[@]}"; do
    FILE_NAME=$(basename "$URL")
    curl -L "$URL" -o "${TARGET_DIR}/${FILE_NAME}" --fail
    [ $? -eq 0 ] && echo "완료: $FILE_NAME" || echo "실패: $FILE_NAME"
done

# 6. oc-mirror 압축 해제 및 퍼미션 설정
echo "--- oc-mirror 설치 중 (/usr/local/bin) ---"
if [ -f "${TARGET_DIR}/${MIRROR_FILE}" ]; then
    # /usr/local/bin에 압축 해제 (sudo 권한 필요할 수 있음)
    tar -xzf "${TARGET_DIR}/${MIRROR_FILE}" -C "$BIN_DIR"
    
    if [ $? -eq 0 ]; then
        # 퍼미션 755 변경
        chmod 755 "${BIN_DIR}/oc-mirror"
        echo "성공: oc-mirror가 ${BIN_DIR}에 설치되었으며 권한이 755로 설정되었습니다."
    else
        echo "오류: 압축 해제에 실패했습니다."
    fi
else
    echo "오류: 압축을 풀 파일(${MIRROR_FILE})이 존재하지 않습니다."
fi

# 7. opm 압축 해제 및 퍼미션 설정
echo "--- op 설치 중 (/usr/local/bin) ---"
if [ -f "${TARGET_DIR}/${OPM_FILE}" ]; then
    # /usr/local/bin에 압축 해제 (sudo 권한 필요할 수 있음)
    tar -xzf "${TARGET_DIR}/${OPM_FILE}" -C "$BIN_DIR"
    
    if [ $? -eq 0 ]; then
        # 퍼미션 755 변경
        if [ -f "${BIN_DIR}/opm-rhel8" ]; then
            mv ${BIN_DIR}/opm-rhel8 "${BIN_DIR}/opm"
        fi
        if [ -f "${BIN_DIR}/opm-rhel9" ]; then
            mv ${BIN_DIR}/opm-rhel9 "${BIN_DIR}/opm"
        fi
        chmod 755 "${BIN_DIR}/opm"
        echo "성공: opm 이 ${BIN_DIR}에 설치되었으며 권한이 755로 설정되었습니다."
    else
        echo "오류: 압축 해제에 실패했습니다."
    fi
else
    echo "오류: 압축을 풀 파일(${OPM_FILE})이 존재하지 않습니다."
fi

echo "--- 모든 작업이 완료되었습니다. ---"
