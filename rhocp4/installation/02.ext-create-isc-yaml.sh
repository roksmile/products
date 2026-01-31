#!/bin/bash

# 1. OCP 버전 입력 (기본값: 4.20.10)
read -p "OCP 버전을 입력하세요 (default: 4.20.10): " OCP_VERSION
OCP_VERSION=${OCP_VERSION:-4.20.10}
SHORT_VER=$(echo $OCP_VERSION | cut -d. -f1-2)

# 패키지 목록 정의
REDHAT_PKGS=(
  "cincinnati-operator"
  "cluster-logging"
  "devworkspace-operator"
  "kubernetes-nmstate-operator"
  "loki-operator"
  "netobserv-operator"
  "node-healthcheck-operator"
  "node-maintenance-operator"
  "openshift-gitops-operator"
  "openshift-pipelines-operator-rh"
  "rhbk-operator"
  "self-node-remediation"
  "web-terminal"
  "servicemeshoperator3"
)

CERTIFIED_PKGS=(
  "elasticsearch-eck-operator-certified"
)

RHOV_PKGS=(
  "kubevirt-hyperconverged"
  "local-storage-operator"
  "metallb-operator"
  "mtc-operator"
  "mtv-operator"
  "redhat-oadp-operator"
  "fence-agents-remediation"
  "lvms-operator"
  "machine-deletion-remediation"
)

TMP_FILE="operator-list.tmp"

# 사전 정리: 기존 임시 파일 삭제
[ -f "$TMP_FILE" ] && rm -f "$TMP_FILE"

# 디렉토리 생성 함수
ensure_dir() {
    [ ! -d "$1" ] && mkdir -p "$1" && echo "디렉토리 생성됨: $1"
}

# [신규] 파일 덮어쓰기 확인 함수
confirm_overwrite() {
    local file_path=$1
    if [ -f "$file_path" ]; then
        read -p "'$file_path' 파일이 이미 존재합니다. 덮어씌우시겠습니까? (y/n): " ans
        if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
            echo "작업을 취소합니다: $file_path"
            return 1 # 덮어쓰지 않음
        fi
    fi
    return 0 # 진행함
}

# 카탈로그 리스트를 임시 파일로 저장하는 함수
fetch_catalog_list() {
    local catalog=$1
    echo "카탈로그 정보를 조회 중입니다: $catalog"
    if ! oc-mirror list operators --catalog="$catalog" > "$TMP_FILE"; then
        echo "오류: 카탈로그 정보를 가져오는데 실패했습니다."
        return 1
    fi
    # 예시: 특정 오퍼레이터의 기본 채널 추출 방법
    # opm render registry.redhat.io/redhat/redhat-operator-index:v4.20 -o json > catalog.json
    # grep '"schema": "olm.package"' -A2 catalog.json |grep 'cincinnati-operator' -A1|grep default|awk -F\" '{ print $4 }' 
    
}

# Operator Channel 추출 함수
get_default_channel() {
    local pkg=$2
    local channel=$(grep "^$pkg" "$TMP_FILE" | awk '{print $2}' | tr -d ' ')
    echo "${channel:-stable}"
}

# 2. 메뉴 출력
echo "-------------------------------------"
echo "생성할 ISC 파일 목록을 선택하세요:"
echo "1. ocp platform"
echo "2. redhat olm"
echo "3. certified olm"
echo "4. all"
echo "-------------------------------------"
read -p "선택 (1-4): " CHOICE

case $CHOICE in
    1|4)
        TARGET="ocp/ocp-isc.yaml"
        ensure_dir "ocp"
        if confirm_overwrite "$TARGET"; then
            cat <<EOF > "$TARGET"
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  platform:
    channels:
    - name: stable-$SHORT_VER
      minVersion: $OCP_VERSION
      maxVersion: $OCP_VERSION
EOF
            echo "$TARGET 생성 완료."
        fi
        [ "$CHOICE" == "1" ] && exit 0
        ;&

    2|4)
        TARGET="olm-redhat/olm-redhat-isc.yaml"
        ensure_dir "olm-redhat"
        if confirm_overwrite "$TARGET"; then
            read -p "RHOV 패키지를 포함하시겠습니까? (y/n): " INCLUDE_RHOV
            
            FINAL_REDHAT_PKGS=("${REDHAT_PKGS[@]}")
            if [[ "$INCLUDE_RHOV" == "y" || "$INCLUDE_RHOV" == "Y" ]]; then
                FINAL_REDHAT_PKGS+=("${RHOV_PKGS[@]}")
            fi

            CATALOG="registry.redhat.io/redhat/redhat-operator-index:v$SHORT_VER"
            fetch_catalog_list "$CATALOG"
            
            {
                echo "kind: ImageSetConfiguration"
                echo "apiVersion: mirror.openshift.io/v2alpha1"
                echo "mirror:"
                echo "  operators:"
                echo "  - catalog: $CATALOG"
                echo "    packages:"
                for PKG in "${FINAL_REDHAT_PKGS[@]}"; do
                    CHANNEL=$(get_default_channel "$CATALOG" "$PKG")
                    echo "    - name: $PKG"
                    echo "      channels:"
                    echo "      - name: $CHANNEL"
                done
            } > "$TARGET"
            
            echo "$TARGET 생성 완료."
            rm -f "$TMP_FILE"
        fi
        [ "$CHOICE" == "2" ] && exit 0
        ;&

    3|4)
        TARGET="olm-certified/olm-certified-isc.yaml"
        ensure_dir "olm-certified"
        if confirm_overwrite "$TARGET"; then
            CATALOG="registry.redhat.io/redhat/certified-operator-index:v$SHORT_VER"
            fetch_catalog_list "$CATALOG"
            
            {
                echo "kind: ImageSetConfiguration"
                echo "apiVersion: mirror.openshift.io/v2alpha1"
                echo "mirror:"
                echo "  operators:"
                echo "  - catalog: $CATALOG"
                echo "    packages:"
                for PKG in "${CERTIFIED_PKGS[@]}"; do
                    CHANNEL=$(get_default_channel "$CATALOG" "$PKG")
                    echo "    - name: $PKG"
                    echo "      channels:"
                    echo "      - name: $CHANNEL"
                done
            } > "$TARGET"
            
            echo "$TARGET 생성 완료."
            rm -f "$TMP_FILE"
        fi
        ;;
    *)
        echo "잘못된 선택입니다."
        exit 1
        ;;
esac

echo "모든 작업이 완료되었습니다."