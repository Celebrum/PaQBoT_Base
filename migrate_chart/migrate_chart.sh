#! /bin/bash

HELM_CMD=$1
V2_CHART_PATH=$2
OCI_REF=$3

${HELM_CMD} push ${V2_CHART_PATH} ${OCI_REF}
