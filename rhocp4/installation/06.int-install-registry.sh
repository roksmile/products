#!/bin/bash

ADMIN_PASSWORD="redhat"

# 1. 도메인 입력 받기
if [ -z "$1" ]; then
    read -p "사용할 도메인을 입력하세요 (예: registry.rok.lab): " DOMAIN
else
    DOMAIN=$1
fi

echo ">>> 설정 도메인: ${DOMAIN}"

# 2. 디렉토리 생성
echo ">>> 디렉토리 생성 중 (/opt/registry/...)"
mkdir -p /opt/registry/{auth,data,certs}

# 3. 인증서 복사
# 실행 위치의 ./server_certs/ 디렉토리에 인증서가 있다고 가정합니다.
echo ">>> 인증서 복사 중..."
if [ -f "./certs/server_certs/${DOMAIN}.crt" ] && [ -f "./certs/server_certs/${DOMAIN}.key" ]; then
    cp ./certs/server_certs/${DOMAIN}.* /opt/registry/certs/
    # 내부 환경 설정용 파일명 표준화 (실행 시 참조용)
    cp ./server_certs/${DOMAIN}.crt /opt/registry/certs/registry.crt
    cp ./server_certs/${DOMAIN}.key /opt/registry/certs/registry.key
else
    echo "오류: ./server_certs/${DOMAIN}.crt 또는 .key 파일이 없습니다."
    exit 1
fi

# 4. 접속 계정 생성 (admin/redhat)
echo ">>> 인증 계정 생성 중..."
htpasswd -bBc /opt/registry/auth/htpasswd admin redhat

# 5. Docker Config 생성 (~/.docker/config.json)
echo ">>> Docker 인증 정보 설정 중..."
AUTH_ENCODED=$(echo -n 'admin:${ADMIN_PASSWORD}' | base64 -w0)
mkdir -p ~/.docker
cat <<EOF > ~/.docker/config.json
{
  "auths": {
    "${DOMAIN}:5000": {
      "auth": "${AUTH_ENCODED}",
      "email": "rkim@redhat.com"
    }
  }
}
EOF

# 6. 기존 컨테이너 제거 (존재할 경우)
podman rm -f mirror-registry 2>/dev/null

# 7. Registry 실행
echo ">>> Registry 컨테이너 실행 중..."
podman run -d --name mirror-registry \
  -p 5000:5000 \
  -v /opt/registry/data:/var/lib/registry:z \
  -v /opt/registry/auth:/auth:z \
  -v /opt/registry/certs:/certs:z \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_HTTP_SECRET="ALongRandomSecretForRegistry" \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  docker.io/library/registry:2

# 8. systemd 서비스 등록
echo ">>> systemd 서비스 등록 중..."
mkdir -p ~/.config/systemd/user
podman generate systemd --name mirror-registry --new --files --name
# 생성된 .service 파일을 systemd 경로로 이동 및 활성화
mv container-mirror-registry.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now container-mirror-registry.service

# 9. 방화벽 오픈 (firewalld가 실행 중인 경우)
if systemctl is-active --quiet firewalld; then
    echo ">>> 방화벽 5000번 포트 오픈 중..."
    sudo firewall-cmd --add-port=5000/tcp --permanent
    sudo firewall-cmd --reload
fi

echo "--------------------------------------------------"
echo "설치가 완료되었습니다."
echo "Registry URL: https://${DOMAIN}:5000"
echo "접속 계정: admin / ${ADMIN_PASSWORD}"
echo "상태 확인: podman ps"
echo "--------------------------------------------------"