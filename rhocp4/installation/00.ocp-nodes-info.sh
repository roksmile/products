#!/bin/bash

OCP_VERSION="4.20.4"
SHORT_VER=$(echo $OCP_VERSION | cut -d. -f1-2)

CLUSTER_NAME="kscada"
BASE_DOMAIN="kdneri.com"

RENDEZVOUS_IP="10.60.1.29"
MACHINE_NETWORK="10.60.1.0/24"
SERVICE_NETWORK="172.30.0.0/16"
CLUSTER_NETWORK="10.128.0.0/14"

NODE_INFO_LIST=(
    "master--mst01.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:11--10.60.1.29--24--10.60.1.1--254"
    "master--mst02.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:12--10.60.1.30--24--10.60.1.1--254"
    "master--mst03.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:13--10.60.1.31--24--10.60.1.1--254"
)
ADD_NODE_INFO_LIST=(
    "worker--ifr01.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:21--10.60.1.40--24--10.60.1.1--254"
    "worker--ifr02.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:22--10.60.1.41--24--10.60.1.1--254"
    "worker--ifr03.kscada.kdneri.com--enp1s0--10:54:00:7d:e1:22--10.60.1.42--24--10.60.1.1--254"
)

SSH_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOR8VQW1SRoAm+79tw21Gg7hIiK7YwnxatIKISraUxVf roksmile@base.rok.lab"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICdUDFsFuk1JTCRKwAnhGS3jRJQvTdBfALs//pTRlEhC root@base.rok.lab"
)

NTP_SERVERS=(
    "10.60.1.21"
    "10.60.1.22"
)

DNS_SERVERS=(
    "10.60.1.21"
    "10.60.1.22"
)

REGISTRY_ADMIN_USER="admin"
REGISTRY_ADMIN_PWD="redhat"
REGISTRY_ADDRESS="nexus.rok.lab:5000"

CONFIG_DIR="$PWD/${CLUSTER_NAME}"

# MASTER_COUNT, WORKER_COUNT, INFRA_COUNT, LOGGING_COUNT 계산 (NODE_INFO_LIST 기반)
# - 역할 필드(항목의 첫 번째 필드)를 소문자로 비교해 카운트합니다.
MASTER_COUNT=0
WORKER_COUNT=0
for entry in "${NODE_INFO_LIST[@]}"; do
  role="${entry%%--*}"
  role_lc=$(echo "$role" | tr '[:upper:]' '[:lower:]')
  case "$role_lc" in
    master)   ((MASTER_COUNT++))  ;;
    worker)   ((WORKER_COUNT++))  ;;
    *) ;;
  esac
done
# export for downstream scripts that may source this file
export MASTER_COUNT WORKER_COUNT