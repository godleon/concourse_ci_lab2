#!/usr/bin/python3

import os, json, copy, sys, shutil, math
from os.path import abspath, dirname
from jinja2 import Environment, FileSystemLoader


# 使用 rally template & 參數產生對應的測試內容
def generate_test(test_tmpl, paras):
    dict_test = copy.deepcopy(test_tmpl[key][0])
    if len(tmpl_test[key]) == 2:
        dict_test = copy.deepcopy(test_tmpl[key][1])

    if "args" in dict_test:
        # 僅測試一次
        if "repetitions" in dict_test["args"]:
            dict_test["args"]["repetitions"] = 1
        # flavor => m1.medium
        if "flavor" in dict_test["args"]:
            dict_test["args"]["flavor"]["name"] = "m1.medium"
        # shared storage 必須把 block migration 設定為 false
        if "block_migration" in dict_test["args"]:
            dict_test["args"]["block_migration"] = False
        # 把 image 從 cirros 改為 Ubuntu
        #if "image" in dict_test["args"]:
        #    dict_test["args"]["image"]["name"] = "ubuntu-1604-amd64.img"
        # 調整測試用的 image 位置
        if "image_location" in dict_test["args"]:
            dict_test["args"]["image_location"] = "http://10.5.91.100:8888/cirros-0.3.5-x86_64-disk.img"
        # 避免太多 security group & rule
        if "security_group_count" in dict_test["args"]:
            dict_test["args"]["security_group_count"] = 1
        if "rules_per_security_group" in dict_test["args"]:
            dict_test["args"]["rules_per_security_group"] = 2

        # For 特定的 cinder scenario
        if "context" in dict_test:
            if "images" in dict_test["context"]:
                if "image_url" in dict_test["context"]["images"]:
                    dict_test["context"]["images"]["image_url"] = "http://10.5.91.100:8888/cirros-0.3.5-x86_64-disk.img"

    if "args" in paras.keys():
        #if "flavor" in paras["args"]:
        #    dict_test["args"]["flavor"]["name"] = "m1.medium"
        if "actions" in paras["args"]:
            dict_test["args"]["actions"] = paras["args"]["actions"]
        if "auto_assign_nic" in paras["args"]:
            dict_test["args"]["auto_assign_nic"] = paras["args"]["auto_assign_nic"]
        if "image_location" in paras["args"]:
            dict_test["args"]["image_location"] = paras["args"]["image_location"]
        if "min_sleep" in paras["args"]:
            dict_test["args"]["min_sleep"] = paras["args"]["min_sleep"]
        if "max_sleep" in paras["args"]:
            dict_test["args"]["max_sleep"] = paras["args"]["max_sleep"]

    if "runner" in paras.keys():
        dict_test["runner"]["type"] = paras["runner"]["type"]
        if paras["runner"]["type"] == "rps":
            dict_test["runner"]["max_cpu_count"] = 1
            if "concurrency" in dict_test["runner"]:
                dict_test["runner"]["rps"] = 1
                del dict_test["runner"]["concurrency"]
        if dict_test["runner"]["times"] == 1:
            dict_test["runner"]["times"] = 10
            if dict_test["runner"]["type"] == "constant":
                dict_test["runner"]["concurrency"] = 10

    if "sla" in paras:
        dict_test["sla"] = {
            "failure_rate": {"max": paras["sla"]["failure_rate"]},
            "max_avg_duration": paras["sla"]["avg"],
            "max_seconds_per_iteration": paras["sla"]["max"]
        }

    # 設定 service quota 為 unlimited
    if "context" not in dict_test:
        dict_test["context"] = {}
    dict_test["context"]["quotas"] = {"cinder": quota_cinder, "nova": quota_nova, "neutron": quota_neutron}

    return dict_test


cur_path = dirname(abspath(__file__))
adjusted_test_path = cur_path + "/out_rally_tests"

path_params = ""
path_upstream_list = ""
if len(sys.argv) == 1:
    path_params = dirname(cur_path) + '/configs/test_params.json'
    path_upstream_list = cur_path + '/upstream_tests.list'
elif len(sys.argv) == 2:
    path_params = dirname(cur_path) + "/configs/" + sys.argv[1]
    path_upstream_list = cur_path + '/upstream_tests.list'
else:
    path_params = sys.argv[1]
    path_upstream_list = sys.argv[2]


# 不同服務的 quota 設定 (設定為 unlimit)
quota_cinder = { "gigabytes": -1, "snapshots": -1, "volumes": -1 }
quota_neutron = {"floatingip": -1, "network": -1, "port": -1, "router": -1, "security_group": -1, "security_group_rule": -1, "subnet": -1}
quota_nova = {"cores": -1, "fixed_ips": -1, "floating_ips": -1, "injected_file_content_bytes": -1, "injected_file_path_bytes": -1, "injected_files": -1, "instances": -1, "key_pairs": -1, "metadata_items": -1, "ram": -1, "security_group_rules": -1, "security_groups": -1, "server_group_members": -1, "server_groups": -1}


template_env = Environment(autoescape=False, loader=FileSystemLoader(cur_path), trim_blocks=False)

with open(path_params, 'r') as f:
    params = json.load(f)

    for key, item in params.items():
        print(item)

        with open(path_upstream_list, 'r') as ul:
            for path_test in ul:
                path_test = path_test.replace("\n", "")
                file_name = path_test[path_test.rindex("/") + 1:]
                tmp_filename = os.getcwd() + "/" + file_name
                shutil.copyfile(path_test, tmp_filename)
                tmpl_output = template_env.get_template(file_name).render()
                tmpl_test = json.loads(tmpl_output)
                os.remove(tmp_filename)

                if list(tmpl_test)[0] == key:
                    adjusted_test = {key: []}

                    # test template 的路徑
                    str = path_test
                    test_category_path = adjusted_test_path + "/" + str[:str.rindex("/")][
                                                                      str[:str.rindex("/")].rindex("/") + 1:]
                    path_test_name = test_category_path + "/" + file_name

                    # 建立不同 service 的目錄
                    if not os.path.exists(test_category_path):
                        os.makedirs(test_category_path)

                    adjusted_test[key].append(generate_test(tmpl_test, item))

                    # 將調整過後的 json 內容寫入檔案
                    with open(path_test_name, 'w') as rt:
                        rt.write(json.dumps(adjusted_test))
                    break

    print("========= Propagation Finished =========")