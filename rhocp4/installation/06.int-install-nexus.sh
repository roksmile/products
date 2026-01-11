#!/bin/bash

### ==============================================================================
### 1. 전역 설정 및 입력 받기
### ==============================================================================
# Nexus Host Name 입력 및 유효성 체크
printf "Nexus Host Name을 입력하세요 (예: nexus.kdneri.com): "
read NEXUS_HOST_NAME

DOMAIN_REGEX="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
if [[ ! $NEXUS_HOST_NAME =~ $DOMAIN_REGEX ]]; then
    echo "[ERROR] 유효하지 않은 도메인 형식입니다: $NEXUS_HOST_NAME"
    exit 1
fi

NEXUS_IMAGE="docker.io/sonatype/nexus3:latest"
HTTPS_PORT="8443"
CUSTOM_PORTS=("5000" "5001")
MEM_TOTAL="4096"

# 실행 계정 감지 및 환경 설정
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    BASE_HOME="/opt/nexus"
    DATA_DIR="/data/nexus"
    SCTL="systemctl"
    SVC_DIR="/etc/systemd/system"
    log_prefix="[Root Mode]"
else
    IS_ROOT=false
    BASE_HOME="/opt/nexus"
    DATA_DIR="/opt/nexus-data"
    SCTL="systemctl --user"
    SVC_DIR="${HOME}/.config/systemd/user"
    log_prefix="[Rootless Mode]"
fi

SSL_PATH="${BASE_HOME}/nexus-etc-ssl"
ENV_PATH="${BASE_HOME}/nexus-env"
SOURCE_CRT="$PWD/server_certs/${NEXUS_HOST_NAME}.crt"
SOURCE_KEY="$PWD/server_certs/${NEXUS_HOST_NAME}.key"

log() { printf "%-15s %-10s %-70s\n" "$log_prefix" "[$1]" "$2"; }

# 원본 인증서 존재 여부 체크
if [[ ! -f "$SOURCE_CRT" ]]; then
    log "ERROR" "원본 인증서 파일이 없습니다: $SOURCE_CRT"
    exit 1
fi

if [[ ! -f "$SOURCE_KEY" ]]; then
    log "ERROR" "원본 키 파일이 없습니다: $SOURCE_KEY"
    exit 1
fi

### ==============================================================================
### 2. 권한 처리 함수
### ==============================================================================
set_permissions() {
    local path=$1
    if [ "$IS_ROOT" = true ]; then
        chown -R 200:200 "$path"
    else
        podman unshare chown -R 200:200 "$path"
    fi
}

### ==============================================================================
### 3. 사전 준비 및 기존 자원 정리
### ==============================================================================
log "INFO" "기존 Nexus 자원 정리 중..."
$SCTL stop container-nexus 2>/dev/null
podman rm -f nexus 2>/dev/null

mkdir -p "$SSL_PATH" "$ENV_PATH" "$DATA_DIR"/{etc,log,tmp,javaprefs}
mkdir -p "$SVC_DIR"

set_permissions "$BASE_HOME"
set_permissions "$DATA_DIR"
chcon -R -t container_file_t "$BASE_HOME" "$DATA_DIR" 2>/dev/null || true

### ==============================================================================
### 4. SSL 인증서 변환 (OpenSSL -> P12 -> JKS)
### ==============================================================================
log "INFO" "인증서 변환 중..."

P12_PATH="${SSL_PATH}/nexus.p12"
JKS_PATH="${SSL_PATH}/keystore.jks"

# 1) PKCS12 생성
openssl pkcs12 -export -in "$SOURCE_CRT" -inkey "$SOURCE_KEY" \
    -out "$P12_PATH" -name nexus -passout pass:password

# [추가] PKCS12 생성 확인
if [[ ! -f "$P12_PATH" ]]; then
    log "ERROR" "PKCS12 파일($P12_PATH) 생성에 실패했습니다. 종료합니다."
    exit 1
fi

# 2) JKS 변환
podman run --rm -v "${SSL_PATH}:/ssl:Z" --entrypoint keytool "$NEXUS_IMAGE" \
    -importkeystore -srckeystore "/ssl/nexus.p12" -srcstoretype PKCS12 \
    -destkeystore "/ssl/keystore.jks" -deststoretype JKS \
    -srcstorepass password -deststorepass password -noprompt >/dev/null 2>&1

# [추가] JKS 변환 확인
if [[ ! -f "$JKS_PATH" ]]; then
    log "ERROR" "JKS 파일($JKS_PATH) 변환에 실패했습니다. 종료합니다."
    exit 1
fi

set_permissions "$P12_PATH"
set_permissions "$JKS_PATH"

### ==============================================================================
### 5. 설정 파일 생성
### ==============================================================================
log "INFO" "Nexus 설정 파일 생성 중..."

cat <<EOF > "${DATA_DIR}/etc/nexus.properties"
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-requestlog.xml,\${jetty.etc}/jetty-https.xml
application-port-ssl=8443
ssl.etc=/opt/sonatype/nexus/etc/ssl
ssl.keystore=keystore.jks
ssl.keystorepassword=password
ssl.keypassword=password
EOF


MEM_HEAP=$(( MEM_TOTAL * 50 / 100 ))
MEM_DIRECT=$(( MEM_TOTAL * 30 / 100 ))

echo "INSTALL4J_ADD_VM_PARAMS=-Xms${MEM_HEAP}m -Xmx${MEM_HEAP}m -XX:MaxDirectMemorySize=${MEM_DIRECT}m -Djava.util.prefs.userRoot=/nexus-data/javaprefs" > "${ENV_PATH}/nexus-runtime.env"

set_permissions "${DATA_DIR}/etc"
set_permissions "${ENV_PATH}"

### ==============================================================================
### 6. Nexus 실행 및 Systemd 등록
### ==============================================================================
log "INFO" "Nexus 컨테이너 및 서비스 등록 중..."

PORT_ARGS="-p ${HTTPS_PORT}:8443"
for port in "${CUSTOM_PORTS[@]}"; do
    PORT_ARGS+=" -p ${port}:${port}"
done

podman run -d \
    --replace \
    --name nexus \
    --memory ${MEM_TOTAL}m \
    --env-file "${ENV_PATH}/nexus-runtime.env" \
    -v "${DATA_DIR}:/nexus-data:Z" \
    -v "${SSL_PATH}:/opt/sonatype/nexus/etc/ssl:Z" \
    $PORT_ARGS \
    "$NEXUS_IMAGE"

pushd "$SVC_DIR" > /dev/null
podman generate systemd --new --files --name nexus >/dev/null
popd > /dev/null

$SCTL daemon-reload
$SCTL enable --now container-nexus.service

### ==============================================================================
### 7. 마무리 및 초기 비밀번호 출력
### ==============================================================================
log "SUCCESS" "설치가 완료되었습니다."
echo "접속 URL: https://${NEXUS_HOST_NAME}:${HTTPS_PORT}"

PW_FILE="${DATA_DIR}/admin.password"
echo "-----------------------------------------------------------"
log "INFO" "초기 관리자(admin) 비밀번호를 확인합니다..."

# Nexus 구동 대기 및 비밀번호 출력 (최대 2분 대기)
count=0
while [ ! -f "$PW_FILE" ] && [ $count -lt 24 ]; do
    sleep 5
    ((count++))
    echo -n "."
done
echo ""

if [ -f "$PW_FILE" ]; then
    printf "초기 비밀번호: \e[32m%s\e[0m\n" "$(cat "$PW_FILE")"
    echo "-----------------------------------------------------------"
else
    log "WARN" "비밀번호 파일이 아직 생성되지 않았습니다 (경로: $PW_FILE)"
fi