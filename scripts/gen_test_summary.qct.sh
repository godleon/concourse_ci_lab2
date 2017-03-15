#!/bin/bash

#set -e # fail fast
#set -x # print commands

# apt-get update >/dev/null
# apt-get -y install git jq >/dev/null

#g_RESOURCE_VER=$(cat git_semver/version)
#mkdir -p $(pwd)/release_summary/${g_RESOURCE_VER}
#g_OUTPUT_SUM_FILE="$(pwd)/release_summary/${g_RESOURCE_VER}/README.md"
g_OUTPUT_SUM_FILE="$1/README.md"
g_OUTPUT_DETAIL_FILE="$1/rally/RAEDME.md"
echo "# Rally Reports" > ${g_OUTPUT_SUM_FILE}
echo "" > ${g_OUTPUT_DETAIL_FILE}
#echo "" > ${g_OUTPUT_SUM_FILE}
#mkdir -p $(pwd)/release_summary/${g_RESOURCE_VER}

#g_PATH_SCEN_TEST=$(find $1/ -name 'scenario_test.html')

PREV_FILENAME=""
PREV_SCEN_NAME=""
PREV_SCEN_MAX=0
CUR_CATE_NAME=""
CUR_SCEN_NAME=""

MAX_CONCURRENCY=0
for f in $(find $1/ -name '(*.html' | sort)
do   
    args=("$f")
    # MAX_CONCURRENCY=$(grep -oP '\"load_profile\":.*\[\[[0-9].*[0-9]\]\]' ${args[@]} | grep -oP '\[\[[0-9].*[0-9]\]\]' | jq 'max_by(.[1])[1]')
    PREV_SCEN_MAX=${MAX_CONCURRENCY}
    if [ `grep -oP '\"load_profile\":.*\[\[[0-9].*[0-9]\]\]\]\], "err' ${args[@]} | wc -l` -eq 0 ]; then
        MAX_CONCURRENCY=$(grep -oP '\"load_profile\":.*\[\[[0-9].*[0-9]\]\]' ${args[@]} | grep -oP '\[\[[0-9].*[0-9]\]\]' | jq 'max_by(.[1])[1]')
    else
        MAX_CONCURRENCY=$(grep -oP '\"load_profile\":.*\[\[[0-9].*[0-9]\]\]\]\], "err' ${args[@]} | grep -oP '\[\[[0-9].*[0-9]\]\]' | jq 'max_by(.[1])[1]')
    fi
    MAX_CONCURRENCY=$(python -c "print(int(round(${MAX_CONCURRENCY})))")
    

    FILE_NAME=${f##*/}
    
    # category name
    CATE_NAME=${f%/*}
    CATE_NAME=${CATE_NAME##*/}
    if [ "${CUR_CATE_NAME}" != "${CATE_NAME}" ]; then
        
        if [ ${PREV_SCEN_MAX} -gt 0 ]; then
            echo "| [${CUR_SCEN_NAME}](https://qct-qxstack.github.io/redhat-osp10/rally/${CUR_CATE_NAME}/${PREV_FILENAME}) | ${PREV_SCEN_MAX} |" | tee -a ${g_OUTPUT_SUM_FILE}
            PREV_SCEN_MAX=0
        fi
        
        # echo "" >> ${g_OUTPUT_SUM_FILE}
        #echo "## ${CATE_NAME}" >> ${g_OUTPUT_SUM_FILE}
        echo "" | tee -a ${g_OUTPUT_SUM_FILE}
        echo "## ${CATE_NAME}" | tee -a ${g_OUTPUT_SUM_FILE}
        echo "" | tee -a ${g_OUTPUT_SUM_FILE}
        echo "| Scenario Name | Max Concurrency |" | tee -a ${g_OUTPUT_SUM_FILE}
        echo "|---------------|-----------------|" | tee -a ${g_OUTPUT_SUM_FILE}

        #TMP_SCEN_NAME=`echo ${FILE_NAME} | grep -oP '\).*(rps|constant)\(' | grep -oP '[a-zA-Z]*\.[a-zA-Z_0-9]*'`
        echo "" | tee -a ${g_OUTPUT_DETAIL_FILE}
        echo "# ${CATE_NAME}" | tee -a ${g_OUTPUT_DETAIL_FILE}
        
        CUR_CATE_NAME=${CATE_NAME}
    fi


    # scenario name
    SCEN_NAME=`echo ${FILE_NAME} | grep -oP '\).*(rps|constant)\(' | grep -oP '[a-zA-Z]*\.[a-zA-Z_0-9]*'`
    if [ "${CUR_SCEN_NAME}" != "${SCEN_NAME}" ]; then

        if [ ${PREV_SCEN_MAX} -gt 0 ]; then
            echo "| [${CUR_SCEN_NAME}](https://qct-qxstack.github.io/redhat-osp10/rally/${CUR_CATE_NAME}/${PREV_FILENAME}) | ${PREV_SCEN_MAX} |" | tee -a ${g_OUTPUT_SUM_FILE}
            PREV_SCEN_MAX=0
        fi

        #echo "" >> ${g_OUTPUT_SUM_FILE}
        echo "" | tee -a ${g_OUTPUT_DETAIL_FILE}
        echo "## ${SCEN_NAME}" | tee -a ${g_OUTPUT_DETAIL_FILE}
        # echo "### ${SCEN_NAME}" >> ${g_OUTPUT_SUM_FILE}
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

    #echo "- ${DATE} ${TIME} ${CUR_SCEN_NAME} ${RUN_TYPE} ====> ${MAX_CONCURRENCY}"

    echo "" | tee -a ${g_OUTPUT_DETAIL_FILE}
    echo "- [${DATE} ${TIME} ${CUR_SCEN_NAME} ${RUN_TYPE}](https://qct-qxstack.github.io/redhat-osp10/rally/${CATE_NAME}/${FILE_NAME}) \`${MAX_CONCURRENCY/.*}\` <img src=\"${ICON_URL}\" width=\"16\" height=\"16\" />" | tee -a ${g_OUTPUT_DETAIL_FILE}

    PREV_FILENAME=${FILE_NAME}
done

echo "| [${SCEN_NAME}](https://qct-qxstack.github.io/redhat-osp10/rally/${CUR_CATE_NAME}/${PREV_FILENAME}) | ${MAX_CONCURRENCY} |" | tee -a ${g_OUTPUT_SUM_FILE}


# cd release_summary/
# git config --global user.email "nobody@concourse.ci"
# git config --global user.name "Concourse"
# git add .
# git commit -m "Rally testing summary - version ${g_RESOURCE_VER}"
# cd -
# git clone release_summary out_release_summary


# rm $(find rally_tests/ -type f -name '*.json' | sort | head -1)
# cd rally_tests/
# git config --global user.email "nobody@concourse.ci"
# git config --global user.name "Concourse"
# git add .
# git commit -m "Rally testing files - version ${g_RESOURCE_VER}"
# cd -
# git clone rally_tests out_rally_tests

echo "Finished!"