#!/bin/bash

set -e # fail fast
set -x # print commands

g_ENTRY_PATH=$(pwd)
g_RESOURCE_VER=$(cat git_semver/version)
g_OUT_DIR=${g_ENTRY_PATH}/out_rally_tests

env

apt-get update >/dev/null
apt-get -y install git python3 python3-jinja2 >/dev/null

git clone ${g_ENTRY_PATH}/rally_tests ${g_OUT_DIR}
rm -rf ${g_OUT_DIR}/*
echo "brach for being rally test queue - version ${g_RESOURCE_VER}" | tee ${g_OUT_DIR}/README.md

cd git_osp/scripts
mkdir -p out_rally_tests
git clone https://github.com/openstack/rally.git >/dev/null
find rally/samples/tasks/scenarios/ -type f -name '*.json' | egrep 'rally/samples/tasks/scenarios/(authenticate|cinder|glance|keystone|neutron|nova|quotas|requests|swift)' > upstream_tests.list

# 移除目的目錄中原有的所有檔案
rm -rf ${g_OUT_DIR}/*

# 根據參數產生對應的測試
chmod +x rally_init.py
# TODO: 目錄參數傳入的部份要寫的有彈性點
./rally_init.py ${CONF_NAME}
#./rally_init.py test_params.json
cp -r out_rally_tests/* ${g_OUT_DIR}/
rm -f upstream_tests.list

cd ${g_OUT_DIR}
git config --global user.email "nobody@concourse.ci"
git config --global user.name "Concourse"
git add .
git commit -m "Rally test initialization - version ${g_RESOURCE_VER}"