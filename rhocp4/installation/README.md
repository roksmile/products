# 폐쇄망 환경에서 RHOCP4를 설치 하기 위한 구성
준비사항
======
## 1. 외부망에서 준비

### 01.ext-download-tools.sh
    ocp설치에 필요한 tool들을 ./tools 로 다운로드 받는다.

### 02.ext-create-isc-yaml.sh
    operator와 ocp설치 파일을 다운받기 위한 isc파일을 생성한다.(ocp,olm-certified,olm-redhat,olm-community)

### 03.ext-mirror-ocp-olm.sh
    02.ext-create-isc.yaml.sh에서 생성한 파일을 가지고 다운로드 받는다.

## 2.내부망에서 준비
### 04.int-install-tools.sh
    ./tools 디렉토리에 있는 파일을 압축해제 하고 /usr/local/bin 디렉토리로 설치한다.

### 05.int-create-certs.sh
    첫번째로 rootCA 인증서를 생성 후 서버용 인증서를 생성한다.

### 06.int-install-{nexus,registry}.sh 
    내부에서 사용할 이미지 레지스트리를 생성한다. nexus,quay,registry 중 선택하여 사용 가능

### 07.int-upload-mirror.sh
    03.ext-mirror-ocp-olm.sh에서 다운로드 받은 파일을 내부 이미지 레지스트리로 업로드 한다.

`ext는 외부망에서 실행가능하며, int는 내부망에서 실행가능하다.`
