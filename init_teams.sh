#!/bin/bash

CONCOURSE_CI_URL="http://10.5.91.100:8080"

# 清除原有的 fly 設定檔
echo '' > ~/.flyrc 

# 建立 main team 設定檔
echo -e "main\nci" | fly -t main login --team-name main --concourse-url ${CONCOURSE_CI_URL}

# 建立 lite team & 登入設定檔
echo -e "y" | fly -t main set-team -n lite --basic-auth-username lite --basic-auth-password ci
echo -e "lite\nci" | fly -t lite login --team-name lite --concourse-url ${CONCOURSE_CI_URL}

# 建立 osp10 team & 登入設定檔
echo -e "y" | fly -t main set-team -n osp10 --basic-auth-username osp10 --basic-auth-password ci
echo -e "osp10\nci" | fly -t osp10 login --team-name osp10 --concourse-url ${CONCOURSE_CI_URL}