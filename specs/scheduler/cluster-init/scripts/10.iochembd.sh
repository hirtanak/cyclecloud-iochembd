#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -ex

echo "starting 10.install_iochembd.sh"

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# disabling selinux
echo "disabling selinux"
setenforce 0
sed -i -e "s/^SELINUX=enforcing$/SELINUX=disabled/g" /etc/selinux/config

SCRIPTUSER=$(jetpack config SCRIPTUSER)
if [[ -z ${SCRIPTUSER}  ]]; then
    CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/jetpackd.log | awk '{print $6}')
    CUSER=${CUSER//\'/}
    CUSER=${CUSER//\`/}
    # After CycleCloud 7.9 and later
    if [[ -z $CUSER ]]; then
        CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/initialize.log | awk '{print $6}' | head -1)
        CUSER=${CUSER//\`/}
        echo ${CUSER} > /shared/CUSER
    fi
else
    CUSER=${SCRIPTUSER}
    echo ${CUSER} > /shared/CUSER
fi

HOMEDIR=/shared/home/${CUSER}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ioChem-BD/scheduler

IOCHEMBD_VERSION=$(jetpack config IOCHEMBD_VERSION)

# License Port Setting
LICENSE=$(jetpack config LICENSE)
(echo "LICENSE_FILE=${LICENSE}") > /etc/profile.d/iochembd.sh
chmod a+x /etc/profile.d/iochembd.sh

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# mkdirctory 
if [[ ! -d ${HOMEDIR}/apps ]]; then
    mkdir -p ${HOMEDIR}/apps
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps
fi 

# 
CMD=$(docker run hello-world) | exit 0
if [[ -z  $CMD ]] || [[ $CMD = "None" ]]; then
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce
    systemctl start docker
    systemctl enable docker
    docker run hello-world
fi

DOCKER_VERSION=1.27.4
if [[ ! -f ${HOMEDIR}/bin/docker-compose-* ]]; then
   mkdir -p ${HOMEDIR}/bin
   chown -R ${CUSER}:${CUSER} ${HOMEDIR}/bin
   curl -L "https://github.com/docker/compose/releases/download/${DOCKER_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ${HOMEDIR}/bin/docker-compose
   chmod +x ${HOMEDIR}/bin/docker-compose
fi

chmod +x ${HOMEDIR}/bin/docker-compose

${HOMEDIR}/bin/docker-compose --version

if [[ ! -d ${HOMEDIR}/iochem-bd-docker  ]]; then
    git clone https://gitlab.com/ioChem-BD/iochem-bd-docker.git ${HOMEDIR}/iochem-bd-docker
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/iochem-bd-docker
#   cd iochem-bd-docker/docker-compose
#   ${HOMEDIR}/bin/docker-compose up
fi

# nohup ${HOMEDIR}/bin/docker-compose up 2>&1 > ${HOMEDIR}/dockerlog.log
CMD=$(grep docker-compose ${HOMEDIR}/.bashrc) | exit 0
if [[ -z $CMD ]]; then
    echo "nohup ${HOMEDIR}/bin/docker-compose up 2>&1 > ${HOMEDIR}/dockerlog.log" >> ${HOMEDIR}/.bashrc
fi
CMD=$(grep iochem-bd-with-data ${HOMEDIR}/.bashrc) | exit 0
if [[ -z $CMD ]]; then
    echo "sudo /usr/bin/docker run -d --ulimit nofile=20000:65535 --name iochem-bd-with-data --add-host test.iochem-bd.org:127.0.0.1 -p 8443:8443 --hostname test.iochem-bd.org iochembd/iochem-bd-docker:latest-with-data" >> ${HOMEDIR}/.bashrc

fi 

#clean up
popd
rm -rf $tmpdir


echo "end of 10.install_iochembd.sh"
