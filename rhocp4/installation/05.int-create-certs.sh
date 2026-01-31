#!/bin/bash

# 1. 디렉토리 설정
ROOT_DIR="$PWD/certs/root_ca"
SERVER_DIR="$PWD/certs/server_certs"

mkdir -p "$ROOT_DIR"
mkdir -p "$SERVER_DIR"

ROOT_KEY="$ROOT_DIR/rootCA.key"
ROOT_CRT="$ROOT_DIR/rootCA.crt"
ROOT_SRL="$ROOT_DIR/rootCA.srl"

while true; do
    echo ""
    echo "==============================================="
    echo "   인증서 관리 시스템 (RedHat GPS)"
    echo "==============================================="
    
    # Root CA 존재 여부에 따른 상태 표시
    if [[ -f "$ROOT_CRT" ]]; then
        EXISTING_CN=$(openssl x509 -noout -subject -in "$ROOT_CRT" | sed -n 's/.*CN=//p')
        echo " [상태] Root CA 설치됨 (CN: $EXISTING_CN)"
        echo " 1. 서버용 인증서 생성 (서버 도메인 입력)"
    else
        echo " [상태] Root CA 없음 (신규 생성이 필요합니다)"
        echo " 1. Root CA 생성 (베이스 도메인 입력)"
    fi
    echo " 2. 종료"
    echo "==============================================="
    read -p "선택하세요 (1/2): " CHOICE

    case $CHOICE in
        1)
            # --- CASE A: Root CA가 없는 경우 (Root 생성) ---
            if [[ ! -f "$ROOT_CRT" ]]; then
                read -p "Root CA의 기반이 될 베이스 도메인을 입력하세요: " BASE_DOMAIN
                
                # 유효성 검사
                if [[ ! $BASE_DOMAIN =~ ^[a-zA-Z1-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    echo "오류: 유효하지 않은 도메인 형식입니다."
                    continue
                fi

                # CN 생성 규칙: 첫 마디 + CA
                FIRST_PART=$(echo "$BASE_DOMAIN" | cut -d'.' -f1)
                AUTO_ROOT_CN="${FIRST_PART}CA"

                echo "--- Root CA를 생성 중입니다 (CN: $AUTO_ROOT_CN) ---"
                openssl genrsa -out "$ROOT_KEY" 4096 2>/dev/null
                SUBJECT_ROOT="/C=KR/ST=Seoul/L=GangNam/O=RedHat/OU=GPS/CN=$AUTO_ROOT_CN"
                openssl req -x509 -new -nodes -key "$ROOT_KEY" -sha256 -days 3650 \
                    -out "$ROOT_CRT" -subj "$SUBJECT_ROOT" 2>/dev/null
                
                echo "Root CA 생성 완료!"
                continue # 생성 후 다시 메뉴로 이동
            fi

            # --- CASE B: Root CA가 있는 경우 (서버 인증서 생성) ---
            echo ""
            read -p "서버용 인증서를 발급할 도메인을 입력하세요 (와일드카드 가능): " SERVER_DOMAIN

            # 와일드카드 포함 유효성 검사
            if [[ ! $SERVER_DOMAIN =~ ^(\*\.)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                echo "오류: 유효하지 않은 도메인 형식입니다."
                continue
            fi

            echo "--- $SERVER_DOMAIN 용 서버 인증서 발급 중 (10년) ---"
            
            # 파일명 안전 처리 (* -> wildcard)
            FILE_NAME=$(echo "$SERVER_DOMAIN" | sed 's/\*/wildcard/g')
            SERVER_KEY="$SERVER_DIR/$FILE_NAME.key"
            SERVER_CSR="$SERVER_DIR/$FILE_NAME.csr"
            SERVER_CRT="$SERVER_DIR/$FILE_NAME.crt"
            EXT_FILE="$SERVER_DIR/$FILE_NAME.ext"

            # 서버 키 및 CSR 생성
            openssl genrsa -out "$SERVER_KEY" 2048 2>/dev/null
            SUBJECT_SERVER="/C=KR/ST=Seoul/L=GangNam/O=RedHat/OU=GPS/CN=$SERVER_DOMAIN"
            openssl req -new -key "$SERVER_KEY" -out "$SERVER_CSR" -subj "$SUBJECT_SERVER" 2>/dev/null

            # SAN 설정 생성
            cat > "$EXT_FILE" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SERVER_DOMAIN
EOF

            # 기존 Root CA로 서명 (10년)
            openssl x509 -req -in "$SERVER_CSR" -CA "$ROOT_CRT" -CAkey "$ROOT_KEY" \
                -CAcreateserial -CAserial "$ROOT_SRL" \
                -out "$SERVER_CRT" -days 3650 -sha256 -extfile "$EXT_FILE" 2>/dev/null

            echo "------------------------------------------------"
            echo "서버 인증서 발행 완료!"
            echo "파일 위치: $SERVER_CRT"
            echo "------------------------------------------------"

            # 임시 파일 정리
            rm -f "$SERVER_CSR" "$EXT_FILE"
            ;;
            
        2)
            echo "프로그램을 종료합니다."
            exit 0
            ;;
            
        *)
            echo "잘못된 입력입니다."
            ;;
    esac
done
