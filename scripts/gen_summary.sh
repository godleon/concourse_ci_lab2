#!/bin/bash

#set -e # fail fast
#set -x # print commands

g_OUTPUT_FILE="test.md"
#g_RESOURCE_VER=$(cat git_semver/version)
g_RESOURCE_VER="0.2.199"
g_PATH_SCEN_TEST=$(find $1/ -name 'scenario_test.html')

CUR_CATE_NAME=""
CUR_SCEN_NAME=""

for f in $(find Sim_GitHub/out_release_ghpages/ -name '(*.html' | sort)
do    
    FILE_NAME=${f##*/}
    CATE_NAME=${f%/*}
    CATE_NAME=${CATE_NAME##*/}
    if [ "${CUR_CATE_NAME}" != "${CATE_NAME}" ]; then
        echo ""
        echo "## ${CATE_NAME}"
        CUR_CATE_NAME=${CATE_NAME}
    fi

    # scenario name
    SCEN_NAME=`echo ${FILE_NAME} | grep -oP '\).*\-[a-zA-Z]'`
    SCEN_NAME=`echo ${SCEN_NAME} | grep -oP '[a-zA-Z]*\.[a-zA-Z_]*'`
    if [ "${CUR_SCEN_NAME}" != "${SCEN_NAME}" ]; then
        echo ""
        echo "### ${SCEN_NAME}"
        CUR_SCEN_NAME=${SCEN_NAME}
    fi

    FULL_TIME=`echo "${FILE_NAME}" | grep -oP '[0-9]{8}_[0-9]{6}'`
    DATE=`echo "${FULL_TIME}" | grep -oP '[0-9]{8}'`
    DATE=`date -d"${DATE}" +%Y-%m-%d`
    TIME=`echo ${FULL_TIME} | grep -oP '_[0-9]{6}'`
    TIME=`echo ${TIME} | grep -oP '[0-9]{6}'`
    TIME="`echo ${TIME} | cut -c 1-2`:`echo ${TIME} | cut -c 3-4`:`echo ${TIME} | cut -c 5-6`"

    RUN_TYPE=`echo ${FILE_NAME} | grep -oP 'constant|rps'`
    RUN_CONCURRENCY=`echo ${FILE_NAME} | grep -oP '\([0-9]{1,4}\-([0-9]*\.[0-9]{1}|[0-9]*)\)'`

    #echo "CATE=${CATE_NAME}, DATE=${DATE}, TIME=${TIME}, SCENARIO=${SCEN_NAME}, RUN_TYPE=${RUN_TYPE}"


    echo ""
    echo "- [${DATE} ${TIME} ${SCEN_NAME} ${RUN_TYPE}${RUN_CONCURRENCY}](https://QCT-QxStack.github.io/redhat-osp10/${g_RESOURCE_VER}/${CATE_NAME}/${FILE_NAME}"
done

echo "Finished!"