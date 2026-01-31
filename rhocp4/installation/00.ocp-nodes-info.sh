#!/bin/bash

OCP_VERSION="4.20.4"
SHORT_VER=$(echo $OCP_VERSION | cut -d. -f1-2)

CLUSTER_NAME="kscada"
BASE_DOMAIN="kdneri.com"

RENDEZVOUS_IP="172.16.120.111"
MACHINE_NETWORK="172.16.120.0/24"
SERVICE_NETWORK="172.30.0.0/16"
CLUSTER_NETWORK="10.128.0.0/14"

NODE_INFO_LIST=(
    "master--mst01.kdneri.com--enp1s0--10:54:00:7d:e1:11--172.16.120.111--24--172.16.120.29--254"
    "master--mst02.kdneri.com--enp1s0--10:54:00:7d:e1:12--172.16.120.112--24--172.16.120.29--254"
    "master--mst03.kdneri.com--enp1s0--10:54:00:7d:e1:13--172.16.120.113--24--172.16.120.29--254"
    "worker--ifr01.kdneri.com--enp1s0--10:54:00:7d:e1:21--172.16.120.121--24--172.16.120.29--254"
    "worker--ifr02.kdneri.com--enp1s0--10:54:00:7d:e1:22--172.16.120.122--24--172.16.120.29--254"
)

SSH_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjb2OTBAVqUt7aMpxbUNBqyZsHxqEoFFOwWU3TKeW9H"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC9i9mgVZGB4wPXAEeGCDvLflvhDJy8WWyrtLQSC5yLa"
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
INFRA_COUNT=0
LOGGING_COUNT=0
for entry in "${NODE_INFO_LIST[@]}"; do
  role="${entry%%--*}"
  role_lc=$(echo "$role" | tr '[:upper:]' '[:lower:]')
  case "$role_lc" in
    master)   ((MASTER_COUNT++))  ;;
    worker)   ((WORKER_COUNT++))  ;;
    infra)    ((INFRA_COUNT++))   ;;
    logging)  ((LOGGING_COUNT++)) ;;
    *) ;;
  esac
done
# export for downstream scripts that may source this file
export MASTER_COUNT WORKER_COUNT INFRA_COUNT LOGGING_COUNT