#!/bin/bash

# 1. 대상 디렉토리 설정
SRC_DIR="tools"
DEST_DIR="/usr/local/bin"

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then 
  echo "오류: 이 스크립트는 sudo 또는 root 권한으로 실행해야 합니다."
  exit 1
fi

echo "OpenShift 관련 도구 설치를 시작합니다..."

---

# 2. butane-amd64 처리 (이름을 butane으로 변경하여 복사)
if [ -f "$SRC_DIR/butane-amd64" ]; then
    cp "$SRC_DIR/butane-amd64" "$DEST_DIR/butane"
    chmod 755 "$DEST_DIR/butane"
    echo "butane 설치 완료 (/usr/local/bin/butane)"
else
    echo " butane-amd64 파일을 찾을 수 없습니다."
fi

# 3. 나머지 .tar.gz 압축 파일 처리
# oc-mirror, openshift-client(oc, kubectl), openshift-install
TAR_FILES=(
    "oc-mirror.rhel9.tar.gz"
    "openshift-client-linux-amd64-rhel9.tar.gz"
    "openshift-install-linux.tar.gz"
)

for FILE in "${TAR_FILES[@]}"; do
    FILE_PATH="$SRC_DIR/$FILE"
    
    if [ -f "$FILE_PATH" ]; then
        echo "$FILE 압축 해제 중..."
        
        # README.md를 제외하고 /usr/local/bin에 직접 압축 해제
        tar -xzf "$FILE_PATH" -C "$DEST_DIR" --exclude='README.md'
        
        echo "$FILE 설치 완료."
    else
        echo "$FILE_PATH 파일을 찾을 수 없습니다."
    fi
done

# 4. 최종 권한 확인 (복사된 모든 바이너리에 실행 권한 부여)
# oc, kubectl, oc-mirror, openshift-install, butane 대상
chmod 755 $DEST_DIR/butane $DEST_DIR/oc $DEST_DIR/kubectl $DEST_DIR/oc-mirror $DEST_DIR/openshift-install 2>/dev/null

echo "---"
echo "모든 작업이 완료되었습니다! 설치된 버전들을 확인하세요."
$DEST_DIR/butane --version | head -n 1
$DEST_DIR/oc version --client