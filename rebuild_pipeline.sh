#!/bin/bash

TEAM_NAME="osp10"
CREDENTIAL_FILE=${1}
PIPELINE_NAME=${2}
PIPELINE_FILE=${3}

echo -e "y" | fly -t ${TEAM_NAME} destroy-pipeline -p ${PIPELINE_NAME}
echo -e "y" | fly -t ${TEAM_NAME} set-pipeline -p ${PIPELINE_NAME} -c ${PIPELINE_FILE} -n --load-vars-from ${CREDENTIAL_FILE}
fly -t ${TEAM_NAME} unpause-pipeline -p ${PIPELINE_NAME}