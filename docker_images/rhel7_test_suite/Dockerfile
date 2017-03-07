FROM registry.access.redhat.com/rhel7.3

MAINTAINER godleon@gmail.com

#RUN subscription-manager register --username ${REDHAT_USER_NAME} --password ${REDHAT_USER_PWD}
#RUN subscription-manager attach --pool=${REDHAT_REG_POOLID}
#RUN subscription-manager repos --disable=*
#RUN subscription-manager repos ${REDHAT_REPO_ENABLED}

# 安裝軟體
#yum -y install git git jq bc wget openstack-tempest python-openstackclient openstack-rally

#yum -y install git jq bc wget openstack-tempest python-openstackclient redhat-lsb-core python27-python-pip gcc gmp-devel iputils libffi-devel libxml2-devel libxslt-devel postgresql-devel openssl-devel python-devel python27-python-devel redhat-rpm-config  >/dev/null
#yum -y install git jq bc wget openstack-tempest python-openstackclient openstack-rally
#subscription-manager remove --all
#subscription-manager unregister
#subscription-manager clean

CMD ["echo","${REDHAT_USER_NAME}"]