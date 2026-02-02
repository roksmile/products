#!/bin/bash

OLD_CATALOG="ocp-registry.kscada.kdneri.com:5000/olm-redhat/redhat/redhat-operator-index:v4.20"
NEW_CATALOG="ocp-registry.kscada.kdneri.com:5001/olm-redhat/redhat/redhat-operator-index:v4.20"

mkdir -p catalogs 

# 1. 원본 렌더링
opm render ${OLD_CATALOG} ${NEW_CATALOG} --skip-tls-verify > raw_index.json

# 2. 채널 내 번들 목록을 합치고 중복 제거 (스마트 필터링)
cat raw_index.json | jq -s '
  # 1. 패키지는 이름 기준으로 하나만 유지
  (map(select(.schema == "olm.package")) | unique_by(.name)) +
  
  # 2. 번들은 버전 이름 기준으로 하나만 유지
  (map(select(.schema == "olm.bundle")) | unique_by(.name)) +
  
  # 3. 채널은 동일 채널명을 그룹화하여 번들 목록(entries)을 합침
  (map(select(.schema == "olm.channel")) | group_by(.package + .name) | map({
    schema: .[0].schema,
    package: .[0].package,
    name: .[0].name,
    entries: (map(.entries[]) | unique_by(.name))
  })) +
  
  # 4. 나머지 메타데이터 유지
  (map(select(.schema != "olm.package" and .schema != "olm.channel" and .schema != "olm.bundle")))
  | .[]' > catalogs/index.json

# 3. 검증
opm validate catalogs/

opm generate dockerfile catalogs/ 

podman build -t ${OLD_CATALOG} -f catalogs.Dockerfile .

rm -rf catalogs raw_index.json catalogs.Dockerfile
