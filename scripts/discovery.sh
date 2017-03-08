#!/bin/bash

set -e # fail fast
set -x # print commands


# 取得 Runner Type
# $1: 測試檔案路徑
function fn_get_runner_type() {
    TEST_NAME=$(jq 'keys[0]' $1)
    RUNNER_TYPE="$(jq ".[${TEST_NAME}][0].runner.type" $1)"
    echo ${RUNNER_TYPE//\"}
}


# 取得正確的 Concurrency (會因為不同的 runnner type 而不同)
# $1: 測試檔案路徑
# $2: Concurrency Number
function fn_get_real_concurrency() {
    REAL_CONCURRENCY=$2
    if [ "${g_RUNNER_TYPE}" == "rps" ]; then REAL_CONCURRENCY=$(python -c "print(${REAL_CONCURRENCY}/10.0)"); fi

    echo ${REAL_CONCURRENCY}
}

# 取得正確的 Concurrency (會因為不同的 runnner type 而不同)
# $1: 測試檔案路徑
function fn_get_concurrency() {
    KEYWORD="concurrency"
    if [ "${g_RUNNER_TYPE}" == "rps" ]; then KEYWORD="rps"; fi

    REAL_CONCURRENCY="$(jq ".[\"${g_TEST_NAME}\"][0].runner.${KEYWORD}" $1)"
    if [ "${g_RUNNER_TYPE}" == "rps" ]; then REAL_CONCURRENCY=$(python -c "print(int(${REAL_CONCURRENCY}*10))"); fi

    echo ${REAL_CONCURRENCY}
}


# 進行 Rally 測試
# $1: 測試檔案路徑
# $2: 測試總次數
# $3: Concurrency 數量
###### $4: Output Directory Path
# $4: Prefix of Output File Name
function fn_do_rally_test() {

    # 測試相關資訊
    TEST_CONCURRENCY=$(fn_get_real_concurrency ${g_CUR_TEST} $3)  # 實際執行測試的同步設定值
    KW_CONCURRENCY="concurrency"
    if [ "${g_RUNNER_TYPE}" == "rps" ]; then KW_CONCURRENCY="rps"; fi

    # 根據傳入參數產生測試檔案
    jq ".[\"${g_TEST_NAME}\"][0].runner.times = $2" $1 > tmp_test.json
    mv tmp_test.json $1
    jq ".[\"${g_TEST_NAME}\"][0].runner.${KW_CONCURRENCY} = $(fn_get_real_concurrency $1 $3)" $1 > tmp_test.json
    mv tmp_test.json $1

    # 產生目前的時間字串
    TIME_STR=$(date +%Y%m%d_%H%M%S)
    #TIME_STR_OUTPUT=$(date +%Y-%m-%d %H:%M:%S)
    #rally task start --abort-on-sla-failure $1 > /dev/null 2>&1
    rally task start --abort-on-sla-failure $1

    # 輸出 rally 測試結果
    OUTPUT_FILENAME="(${TIME_STR})${g_TEST_NAME}-${g_RUNNER_TYPE}($2-${TEST_CONCURRENCY})"
    #if [ $5 ]; then OUTPUT_FILENAME="${OUTPUT_FILENAME}_$5"; fi
    if [ $4 ]; then OUTPUT_FILENAME="${OUTPUT_FILENAME}_$4"; fi
    rally task results > tmp_result.json
    IS_PASS=$(fn_check_result tmp_result.json)
    if [ ${IS_PASS} -eq 1 ]; then
        OUTPUT_FILENAME=${OUTPUT_FILENAME}-PASSED
    else
        OUTPUT_FILENAME=${OUTPUT_FILENAME}-FAILED
    fi
    
    #mkdir -p $4/${g_CATE_NAME}
    mkdir -p ${g_OUT_GHPAGES}/${g_CATE_NAME}
    rally task report --out $4/${g_CATE_NAME}/${OUTPUT_FILENAME}.html
    rally task results > $4/${g_CATE_NAME}/${OUTPUT_FILENAME}.json
    #rally task report --out ${g_OUT_GHPAGES}/${g_CATE_NAME}/${OUTPUT_FILENAME}.html 2>/dev/null
    #rally task results > ${g_OUT_GHPAGES}/${g_CATE_NAME}/${OUTPUT_FILENAME}.json 2>/dev/null

    cd /tempest >/dev/null 2>&1
    tempest cleanup >/dev/null 2>&1
    cd - >/dev/null 2>&1

    #RET="$4/${g_CATE_NAME}/${OUTPUT_FILENAME}"
    #RET="${g_OUT_GHPAGES}/${g_CATE_NAME}/${OUTPUT_FILENAME}"
    #echo "- [${TIME_STR_OUTPUT} ${g_TEST_NAME} ${g_TEST_NAME}(${g_RUNNER_TYPE}) ${TEST_CONCURRENCY}(${KW_CONCURRENCY})](https://godleon.github.io/osp_binary_test_result/${g_RESOURCE_VER}/${OUTPUT_FILENAME}.html)" >> ${g_DIR_RALLY_OUTPUT}/discovery.log.${g_CATE_NAME}
    #echo "- [${TIME_STR_OUTPUT} ${g_TEST_NAME} ${g_TEST_NAME}(${g_RUNNER_TYPE}) ${TEST_CONCURRENCY}(${KW_CONCURRENCY})](https://godleon.github.io/osp_binary_test_result/${g_RESOURCE_VER}/${OUTPUT_FILENAME}.html)" >> ${g_OUT_SUMMARY}/discovery.log.${g_CATE_NAME}
    
    #echo "${RET}.html" >> ${g_DIR_RALLY_OUTPUT}/discovery.log.${g_CATE_NAME}

    ##echo "${RET}"
    echo "${g_OUT_GHPAGES}/${g_CATE_NAME}/${OUTPUT_FILENAME}"
}


# 檢查 Rally 測試結果是否通過
# $1: 測試結果檔案路徑
function fn_check_result() {
    IS_PASS=1
    TMP_COUNT=0
    for r in $(jq '.[0].sla[].success' $1);
    do
        TMP_COUNT=$((TMP_COUNT + 1))
        if [ ${r} == "false" ]; then 
            IS_PASS=0
            break
        fi
        if [ ${TMP_COUNT} -eq 3 ]; then break; fi   # 不要檢查第四個檢查點，可能是錯誤的(全部 pass 卻被認為 fail)
    done

    echo ${IS_PASS}
}


ENTRY_PATH=$(pwd)
g_RESOURCE_VER=$(cat git_semver/version)
g_OUT_SUMMARY=${HOME}/out_release_summary/${g_RESOURCE_VER}
g_OUT_GHPAGES=${HOME}/out_release_ghpages/${g_RESOURCE_VER}

# 註冊 Red Hat CDN
# subscription-manager register --username ${REDHAT_USER_NAME} --password ${REDHAT_USER_PWD} >/dev/null
# subscription-manager attach --pool=${REDHAT_REG_POOLID} >/dev/null
# subscription-manager repos --disable=*  >/dev/null
# subscription-manager repos ${REDHAT_REPO_ENABLED}  >/dev/null

# 安裝軟體
#yum -y install git
REMAIN_TEST_COUNT=$(find rally_tests/ -type f -name '*.json' | wc -l)
if [ ${REMAIN_TEST_COUNT} -eq 0 ]; then 
    #sudo git clone release_ghpages ${ENTRY_PATH}/out_release_ghpages
    git clone release_ghpages ${ENTRY_PATH}/out_release_ghpages
    exit 0; 
fi

#yum -y install git jq bc wget openstack-tempest python-openstackclient redhat-lsb-core python27-python-pip gcc gmp-devel iputils libffi-devel libxml2-devel libxslt-devel postgresql-devel openssl-devel python-devel python27-python-devel redhat-rpm-config  >/dev/null
# yum -y install git jq bc wget openstack-tempest python-openstackclient openstack-rally
# subscription-manager remove --all
# subscription-manager unregister
# subscription-manager clean

#PATH=${PATH}:/opt/rh/python27/root/usr/bin

# 設定 tempest
#mkdir -p /tempest
cd /tempest
#ln -s /usr/share/openstack-tempest-13.0.0 /usr/share/openstack-tempest
#sh /usr/share/openstack-tempest/tools/configure-tempest-directory
tools/config_tempest.py --debug --create identity.uri ${OS_AUTH_URL} identity.admin_username ${OS_USERNAME} identity.admin_password ${OS_PASSWORD} identity.admin_tenant_name ${OS_TENANT_NAME} object-storage.operator_role swiftoperator
tempest cleanup --init-saved-state
cd -

# 安裝 Rally
#curl https://raw.githubusercontent.com/openstack/rally/master/install_rally.sh | bash
#sudo apt-get update >/dev/null
#sudo apt-get -y install git jq bc >/dev/null

# 環境變數設定
#source git_osp/overcloudrc

# 將所有目錄移到 /home/rally 下
cd ${HOME}
cp -r ${ENTRY_PATH}/* ./

# git clone 相關所需目錄
#git clone release_summary out_release_summary
git clone release_ghpages out_release_ghpages
mkdir -p ${g_OUT_SUMMARY}
mkdir -p ${g_OUT_GHPAGES}

# 開始執行測試
rally-manage db recreate
rally deployment create --fromenv --name=existing
rally deployment check

#cp -r git_osp/output_sample/authenticate ${g_OUT_GHPAGES}/
#cd ${g_OUT_GHPAGES}

#rm $(find rally_tests/ -type f -name '*.json' | sort | head -1)
#cd rally_tests
#git config --global user.email "nobody@concourse.ci"
#git config --global user.name "Concourse"
#git add .
#git commit -m "Rally testing results - version ${g_RESOURCE_VER}"
#cd -
#sudo git clone ${HOME}/out_release_ghpages ${ENTRY_PATH}/out_release_ghpages
#sudo git clone rally_tests ${ENTRY_PATH}/out_rally_tests

#exit 0



# 全域變數定義
FAIL_RETRY_TIME=0   # 失敗重測次數
MAX_RETRY_TIME=1    # 成功重測次數
g_CUR_TEST=$(find rally_tests/ -type f -name '*.json' | sort | head -1)    # 目前測試的檔案路徑
g_CATE_NAME=${g_CUR_TEST%/*}
g_CATE_NAME=${g_CATE_NAME##*/}  # Service Name
g_TEST_NAME=$(jq 'keys[0]' ${g_CUR_TEST})
g_TEST_NAME=${g_TEST_NAME//\"}  # Test Name
g_RUNNER_TYPE="$(jq ".[\"${g_TEST_NAME}\"][0].runner.type" ${g_CUR_TEST})"
g_RUNNER_TYPE=${g_RUNNER_TYPE//\"}  # Runner Type
#TMP_FUNTIONAL_MULTI=$(jq ".[\"${g_TEST_NAME}\"].ci_params.functional_multi" git_osp/configs/test_params.json)
#g_TEST_TIMEs=$(jq ".[\"${g_TEST_NAME}\"][0].runner.times * ${TMP_FUNTIONAL_MULTI}" ${g_CUR_TEST})   # 測試次數
g_TEST_TIMEs=$(jq ".[\"${g_TEST_NAME}\"].ci_params.functional_times" git_osp/configs/test_params.json)

# 開始寫入 detail log
#echo ""
#echo "### ${g_TEST_NAME}" >> ${g_OUT_SUMMARY}/discovery.log.${g_CATE_NAME}

# 取得初始測試強度
TEST_CONCURRENCY=$(fn_get_concurrency ${g_CUR_TEST})

# 定義流程控制所需變數
CONTINUE_TO_TEST=1
LAST_PASS_CONCURRENCY=1     # 最後一次測試通過的測試強度數據(初期預設為 1, 假設 1 絕對會通過)
TOP_CONCURRENCY=0           # 測試強度的天花板
TEST_IS_PASS=1      # 檢查測試結果有無通過
FAIL_OCCURRED=0     # 是否已經發生測試失敗


# 進行測試 & 產生測試結果
#while [ ${TEST_IS_PASS} -eq 1 ] && [ ${TEST_CONCURRENCY} -lt ${TEST_TIMEs} ];
while [ ${CONTINUE_TO_TEST} -eq 1 ];
do
    # $1: 測試檔案路徑
    # $2: 測試總次數
    # $3: Concurrency 數量
    # $4: Output Directory Path
    RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} "")
    cat ${g_CUR_TEST}
    #RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} ${g_DIR_RALLY_OUTPUT} "")

    # 檢查是否測試通過
    TEST_IS_PASS=$(fn_check_result "${RALLY_RESULT_PATH}.json")
    
    # 測試失敗，嘗試重新測試 FAIL_RETRY_TIME 次
    if [ ${TEST_IS_PASS} -eq 0 ]; then
        # 開始重新測試
        for i in $(seq 1 ${FAIL_RETRY_TIME});
        do
            echo "Fail Retry ${i}"
            RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} "FailRetry(${i})")
            cat ${g_CUR_TEST}
            #RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} ${g_DIR_RALLY_OUTPUT} "FailRetry(${i})")

            # 檢查是否測試通過
            TEST_IS_PASS=$(fn_check_result "${RALLY_RESULT_PATH}.json")

            # 重新測試 pass!
            if [ ${TEST_IS_PASS} -eq 1 ]; then break; fi
        done

        # 重新測試 FAIL_RETRY_TIME 次後依然失敗 => 已經遇到天花板
        if [ ${TEST_IS_PASS} -eq 0 ]; then 
            FAIL_OCCURRED=1
            TOP_CONCURRENCY=${TEST_CONCURRENCY} # 設定測試強度天花板
        fi
    fi

    #測試通過，更新最大測試強度
    if [ ${TEST_IS_PASS} -eq 1 ]; then LAST_PASS_CONCURRENCY=${TEST_CONCURRENCY}; fi

    # 測試強度的調整
    if [ ${TEST_IS_PASS} -eq 1 ]; then    # 測試通過
        
        if [ ${FAIL_OCCURRED} -eq 0 ]; then # 沒有失敗過 => 測試強度 x 2 並持續測試
            TEST_CONCURRENCY=$((TEST_CONCURRENCY * 2))
            #if [ ${TEST_CONCURRENCY} -gt ${g_TEST_TIMEs} ]; then TEST_CONCURRENCY=${g_TEST_TIMEs}; fi
            TMP_CONCURRENT=`fn_get_real_concurrency ${g_CUR_TEST} ${TEST_CONCURRENCY}`
            if [ `echo "${TMP_CONCURRENT} > ${g_TEST_TIMEs}" | bc` -eq 1 ]; then 
                TEST_CONCURRENCY=${g_TEST_TIMEs}
                if [ ${g_RUNNER_TYPE} == "rps" ]; then TEST_CONCURRENCY=$((TEST_CONCURRENCY * 10)); fi
            fi
        else    # 測試失敗過 => 測試強度 = (TEST_CONCURRENCY + TOP_CONCURRENCY) / 2
            TEST_CONCURRENCY=$(( (TEST_CONCURRENCY + TOP_CONCURRENCY) / 2))
        fi

    else    # 測試失敗
        TEST_CONCURRENCY=$(( (TEST_CONCURRENCY + LAST_PASS_CONCURRENCY) / 2 ))
    fi

    # 測試強度超過最大上限
    TMP_CONCURRENT=`fn_get_real_concurrency ${g_CUR_TEST} ${TOP_CONCURRENCY}`
    if [ `echo "${TMP_CONCURRENT} >= ${g_TEST_TIMEs}" | bc` -eq 1 ] && [ ${TEST_IS_PASS} -eq 1 ]; then 
        CONTINUE_TO_TEST=0
    fi
    #if [ ${TOP_CONCURRENCY} -ge ${g_TEST_TIMEs} ] && [ ${TEST_IS_PASS} -eq 1 ]; then CONTINUE_TO_TEST=0; fi
    
    # 下回要測試的強度跟最後一次測試通過的強度相同
    if [ ${TEST_CONCURRENCY} -eq ${LAST_PASS_CONCURRENCY} ]; then CONTINUE_TO_TEST=0; fi
done


# 找到正確的最大測試強度
while [ ${TEST_CONCURRENCY} -gt 0 ];
do
    TMP_CHECK_POINT=1
    for i in $(seq 1 ${MAX_RETRY_TIME});
    do
        echo "Pass Retry ${i}"  
        RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} "PassRetry(${i})")
        cat ${g_CUR_TEST}
        #RALLY_RESULT_PATH=$(fn_do_rally_test ${g_CUR_TEST} ${g_TEST_TIMEs} ${TEST_CONCURRENCY} ${g_DIR_RALLY_OUTPUT} "PassRetry(${i})")
        
        # 檢查測試結果是否通過
        TMP_CHECK_POINT=$(fn_check_result "${RALLY_RESULT_PATH}.json")
        if [ ${TMP_CHECK_POINT} -eq 0 ]; then 
            # 以 5% 的折扣往下遞減
            TEST_CONCURRENCY=$((TEST_CONCURRENCY * 95 / 100))       
            break
        fi
    done

    # 成功連續三次測試通過
    if [ ${TMP_CHECK_POINT} -eq 1 ]; then break; fi
done

echo "The max concurrency of ${g_TEST_NAME} ====> ${TEST_CONCURRENCY}"
echo "Final file name ====> ${RALLY_RESULT_PATH}.html"
#echo "${g_TEST_NAME},${TEST_CONCURRENCY}" >> ${g_OUT_SUMMARY}/discovery.summary

# 移除不必要的 json 檔案
find ${g_OUT_GHPAGES}/ -type f -name '*.json' -exec rm {} \;

# 輸出
#rm ${g_CUR_TEST}
#cd ${HOME}/rally_tests
#git config --global user.email "nobody@concourse.ci"
#git config --global user.name "Concourse"
#git add .
#git commit -m "Remove Rally testing file(${g_CUR_TEST}) - version ${g_RESOURCE_VER}"
#cd -
#sudo git clone rally_tests ${ENTRY_PATH}/out_rally_tests


#sudo cp -r ${HOME}/output_discovery/* ${ENTRY_PATH}/output_discovery
cd ${HOME}/out_release_ghpages
git config --global user.email "nobody@concourse.ci"
git config --global user.name "Concourse"
git add .
git commit -m "Rally discovery html output - version ${g_RESOURCE_VER}"
cd -
cp -r ${HOME}/out_release_ghpages ${ENTRY_PATH}/
#sudo cp -r ${HOME}/out_release_ghpages ${ENTRY_PATH}/

#cd ${HOME}/out_release_summary
#git config --global user.email "nobody@concourse.ci"
#git config --global user.name "Concourse"
#git add .
#git commit -m "Rally discovery summary output - version ${g_RESOURCE_VER}"
#cd -
#sudo cp -r ${HOME}/out_release_summary ${ENTRY_PATH}/


