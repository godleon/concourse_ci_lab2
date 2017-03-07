#!/bin/bash

set -e # fail fast
set -x # print commands

g_ENTRY_PATH=$(pwd)
g_RESOURCE_VER=$(cat git_semver/version)
g_OUT_DIR=${g_ENTRY_PATH}/out_release_ghpages
g_OUT_TMP_DIR=${HOME}/out_release_ghpages

env

# 安裝軟體
sudo apt-get update >/dev/null
sudo apt-get -y install git jq >/dev/null

# 環境變數設定
source git_osp/overcloudrc

# git clone 相關所需目錄
sudo git clone ${g_ENTRY_PATH}/release_ghpages ${g_OUT_DIR}

# 將所有目錄移到 /home/rally 下
cd ${HOME}
cp -r ${g_ENTRY_PATH}/* ./
mkdir -p ${g_OUT_TMP_DIR}/${g_RESOURCE_VER}
#rm -rf ${g_OUT_TMP_DIR}/${g_RESOURCE_VER}/*

# 產生進行 scenatio test 用的 json 檔案
echo "{}" > /tmp/tmp_content.json
for f in $(find rally_tests/ -type f -name '*.json')
do
    if [ "`jq '.[][0].args.flavor.name' $f`" == "null" ]; then
        jq '.' $f > /tmp/flavor_changed.json
    else
        jq '.[][0].args.flavor.name="m1.tiny"' $f > /tmp/flavor_changed.json
    fi
    jq -s '.[0] * .[1]' /tmp/flavor_changed.json /tmp/tmp_content.json > /tmp/scenario_test.json
    cp /tmp/scenario_test.json /tmp/tmp_content.json
done

# 開始執行測試 & 產生報表
rally-manage db recreate
rally deployment create --fromenv --name=existing
rally deployment check
rally task start /tmp/scenario_test.json
rally task report --out ${g_OUT_TMP_DIR}/${g_RESOURCE_VER}/scenario_test.html


sudo cp -r ${g_OUT_TMP_DIR}/${g_RESOURCE_VER} ${g_OUT_DIR}/
cd ${g_OUT_DIR}
sudo git config --global user.email "nobody@concourse.ci"
sudo git config --global user.name "Concourse"
sudo git add .
sudo git commit -m "Rally test files - version ${g_RESOURCE_VER}"