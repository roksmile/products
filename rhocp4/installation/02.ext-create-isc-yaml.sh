#!/bin/bash

# 1. 버전 및 기본 정보 입력
echo -n "OCP 버전을 입력하세요 (예: 4.20.1): "
read OCP_VERSION
SHORT_VER=$(echo $OCP_VERSION | cut -d. -f1-2)

# 함수 정의: OCP ISC 생성
create_ocp() {
    if [ ! -d "ocp" ]; then
        mkdir ocp
        echo "'ocp' 디렉토리를 생성했습니다."
    fi
    cat <<EOF > ocp/ocp-isc.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v2alpha1
mirror:
  platform:
    channels:
    - name: stable-$SHORT_VER
      minVersion: $OCP_VERSION
      maxVersion: $OCP_VERSION
EOF
    echo ">> 파일 생성 완료: ocp/ocp-isc.yaml"
}

# 함수 정의: Certified OLM ISC 생성
create_certified() {
    if [ ! -d "certified-olm" ]; then
        mkdir certified-olm
        echo "'certified-olm' 디렉토리를 생성했습니다."
    fi
    cat <<EOF > certified-olm/certified-olm-isc.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
mirror:
  operators:
  - catalog: registry.redhat.io/redhat/certified-operator-index:v$SHORT_VER
    packages:
    - name: elasticsearch-eck-operator-certified
      channels:
      - name: stable
EOF
    echo ">> 파일 생성 완료: certified-olm/certified-olm-isc.yaml"
}

# 함수 정의: RedHat OLM ISC 생성
create_redhat() {
    if [ ! -d "redhat-olm" ]; then
        mkdir redhat-olm
        echo "'redhat-olm' 디렉토리를 생성했습니다."
    fi

    echo -n "RHOV(OpenShift Virtualization) 용도로 사용하시겠습니까? (y/n): "
    read RHOV_ANS

    cat <<EOF > redhat-olm/redhat-olm-isc.yaml
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
mirror:
  operators:
  - catalog: registry.redhat.io/redhat/redhat-operator-index:v$SHORT_VER
    packages:
    - name: cincinnati-operator
      channels:
      - name: v1
    - name: cluster-logging
      channels:
      - name: stable-6.4
    - name: devworkspace-operator
      channels:
      - name: fast
    - name: kubernetes-nmstate-operator
      channels:
      - name: stable
    - name: loki-operator
      channels:
      - name: stable-6.4
    - name: netobserv-operator
      channels:
      - name: stable
    - name: node-healthcheck-operator
      channels:
      - name: stable
    - name: node-maintenance-operator
      channels:
      - name: stable
    - name: openshift-gitops-operator
      channels:
      - name: latest
    - name: openshift-pipelines-operator-rh
      channels:
      - name: latest
    - name: rhbk-operator
      channels:
      - name: stable-v26.4
    - name: self-node-remediation
      channels:
      - name: stable
    - name: web-terminal
      channels:
      - name: fast
EOF

    if [[ "$RHOV_ANS" =~ ^[yY]$ ]]; then
        cat <<EOF >> redhat-olm/redhat-olm-isc.yaml
    - name: kubevirt-hyperconverged
    - name: local-storage-operator
    - name: metallb-operator
    - name: mtc-operator
    - name: mtv-operator
    - name: redhat-oadp-operator
    - name: fence-agents-remediation
    - name: lvms-operator
    - name: machine-deletion-remediation
EOF
        echo ">> RHOV 관련 Operator 설정이 추가되었습니다."
    fi
    echo ">> 파일 생성 완료: redhat-olm/redhat-olm-isc.yaml"
}

# 2. 메뉴 선택
echo "------------------------------------------"
echo "생성할 설정을 선택하세요:"
echo "1) OCP Platform (ocp-isc.yaml)"
echo "2) Certified OLM (certified-olm-isc.yaml)"
echo "3) RedHat OLM (redhat-olm-isc.yaml)"
echo "4) 전체 생성 (All)"
echo "------------------------------------------"
echo -n "선택 (1-4): "
read MENU_CHOICE

case $MENU_CHOICE in
    1)
        create_ocp
        ;;
    2)
        create_certified
        ;;
    3)
        create_redhat
        ;;
    4)
        create_ocp
        create_certified
        create_redhat
        ;;
    *)
        echo "잘못된 선택입니다. 프로그램을 종료합니다."
        exit 1
        ;;
esac

echo "------------------------------------------"
echo "모든 작업이 완료되었습니다."