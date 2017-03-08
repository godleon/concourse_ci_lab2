#!/bin/bash

set -e # fail fast
set -x # print commands

apt-get update >/dev/null
apt-get -y install git jq >/dev/null

g_RESOURCE_VER=$(cat git_semver/version)
mkdir -p $(pwd)/release_summary/${g_RESOURCE_VER}
g_OUTPUT_FILE="$(pwd)/release_summary/${g_RESOURCE_VER}/README.md"
echo "" > ${g_OUTPUT_FILE}
mkdir -p $(pwd)/release_summary/${g_RESOURCE_VER}

g_PATH_SCEN_TEST=$(find $1/ -name 'scenario_test.html')

CUR_CATE_NAME=""
CUR_SCEN_NAME=""

for f in $(find $1/ -name '(*.html' | sort)
do   
    args=("$f")
    #MAX_CONCURRENCY=$(grep -oP '\"load_profile\":.*, \"errors' ${args[@]} | grep -oP '\[\[.*\]\]' | grep -oP '\[\[[0-9].*[0-9]\]\]' | jq 'max_by(.[1])[1]')
    MAX_CONCURRENCY=$(grep -oP '\"load_profile\":.*\[\[[0-9].*[0-9]\]\]' ${args[@]} | grep -oP '\[\[[0-9].*[0-9]\]\]' | jq 'max_by(.[1])[1]')
    echo "MAX_CONCURRENCY = ${MAX_CONCURRENCY}"

    FILE_NAME=${f##*/}
    CATE_NAME=${f%/*}
    CATE_NAME=${CATE_NAME##*/}
    if [ "${CUR_CATE_NAME}" != "${CATE_NAME}" ]; then
        echo "" >> ${g_OUTPUT_FILE}
        echo "## ${CATE_NAME}" >> ${g_OUTPUT_FILE}
        CUR_CATE_NAME=${CATE_NAME}
    fi

    # scenario name
    SCEN_NAME=`echo ${FILE_NAME} | grep -oP '\).*(rps|constant)\('`
    SCEN_NAME=`echo ${SCEN_NAME} | grep -oP '[a-zA-Z]*\.[a-zA-Z_]*'`
    if [ "${CUR_SCEN_NAME}" != "${SCEN_NAME}" ]; then
        echo "" >> ${g_OUTPUT_FILE}
        echo "### ${SCEN_NAME}" >> ${g_OUTPUT_FILE}
        CUR_SCEN_NAME=${SCEN_NAME}
    fi

    FULL_TIME=`echo "${FILE_NAME}" | grep -oP '[0-9]{8}_[0-9]{6}'`
    DATE=`echo "${FULL_TIME}" | grep -oP '[0-9]{8}'`
    DATE=`date -d"${DATE}" +%Y-%m-%d`
    TIME=`echo ${FULL_TIME} | grep -oP '_[0-9]{6}'`
    TIME=`echo ${TIME} | grep -oP '[0-9]{6}'`
    TIME="`echo ${TIME} | cut -c 1-2`:`echo ${TIME} | cut -c 3-4`:`echo ${TIME} | cut -c 5-6`"

    RUN_TYPE=`echo ${FILE_NAME} | grep -oP '(constant|rps)\(.*\)'`

    # Icon url
    ICON_URL="http://www.bridging-the-gap.com/wp-content/uploads/2015/04/ok-128x128.png"
    if [ "`echo "${FILE_NAME}" | grep -oP '(PASSED|FAILED)'`" == "FAILED" ]; then 
        ICON_URL="https://foreverbcn-wpengine.netdna-ssl.com/wp-content/uploads/2014/12/Alarm-Error-icon.png"
    fi

    #echo "CATE=${CATE_NAME}, DATE=${DATE}, TIME=${TIME}, SCENARIO=${SCEN_NAME}, RUN_TYPE=${RUN_TYPE}"
    echo "" >> ${g_OUTPUT_FILE}
    echo "- [${DATE} ${TIME} ${CUR_SCEN_NAME} ${RUN_TYPE}](https://godleon.github.io/osp_binary_test_result/${g_RESOURCE_VER}/${CATE_NAME}/${FILE_NAME}) \`${MAX_CONCURRENCY/.*}\` <img src=\"${ICON_URL}\" width=\"16\" height=\"16\" \/>" >> ${g_OUTPUT_FILE}
done

cd release_summary/
git config --global user.email "nobody@concourse.ci"
git config --global user.name "Concourse"
git add .
git commit -m "Rally testing summary - version ${g_RESOURCE_VER}"
cd -
git clone release_summary out_release_summary


rm $(find rally_tests/ -type f -name '*.json' | sort | head -1)
cd rally_tests/
git config --global user.email "nobody@concourse.ci"
git config --global user.name "Concourse"
git add .
git commit -m "Rally testing files - version ${g_RESOURCE_VER}"
cd -
git clone rally_tests out_rally_tests

echo "Finished!"