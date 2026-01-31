#!/bin/bash

# operatorhub-disabled.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/operatorhub-disabled.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: config.openshift.io/v1
kind: OperatorHub
metadata:
  name: cluster
spec:
  disableAllDefaultSources: true
EOF
echo "Success: Generated $OUTPUT_FILE"

# sample-operator.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/sample-operator.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: samples.operator.openshift.io/v1
kind: Config
metadata:
  name: cluster
spec:
  architectures:
  - x86_64
  managementState: Removed
EOF
echo "Success: Generated $OUTPUT_FILE"

# cs-redhat-operator-index.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/cs-redhat-operator-index.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cs-redhat-operator-index
  namespace: openshift-marketplace
spec:
  image: ${REGISTRY_ADDRESS}/olm-redhat/redhat/redhat-operator-index:v4.20
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 20m
EOF
echo "Success: Generated $OUTPUT_FILE"

# idms-olm-redhat.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/idms-olm-redhat.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: olm-redhat
spec:
  imageDigestMirrors:
  - mirrors:
    - ${REGISTRY_ADDRESS}/olm-redhat
    source: registry.redhat.io
EOF
echo "Success: Generated $OUTPUT_FILE"

# master-kubeletconfig.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/master-kubeletconfig.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: master-set-kubelet-config
spec:
  autoSizingReserved: true
  logLevel: 3
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/master: ""
EOF
echo "Success: Generated $OUTPUT_FILE"

# worker-kubeletconfig.yaml 생성
OUTPUT_FILE="${CONFIG_DIR}/openshift/worker-kubeletconfig.yaml"
cat > "${OUTPUT_FILE}" << EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: worker-set-kubelet-config
spec:
  autoSizingReserved: true
  logLevel: 3
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/worker: ""
EOF
echo "Success: Generated $OUTPUT_FILE"