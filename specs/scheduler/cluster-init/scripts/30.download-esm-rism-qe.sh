#!/bin/bash
# Copyright (c) 2019 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=esm-rism-qe
echo "starting 30.execute-${SW}.sh"

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
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ioChem-BD/execute

# get Quantum ESPRESSO version
QE_VERSION=$(jetpack config QE_VERSION)
# get esm-rism-qe parameters
QE_DL_URL=$(jetpack config QE_DL_URL)
QE_DL_VER=${QE_DL_URL##*/}
echo ${QE_DL_VER}
# https://staff.aist.go.jp/minoru.otani/qe-6.1.0-715-g3b2f53c9f.tgz

# get Quantum ESPRESSO version
if [[ ${QE_DL_VER} = None ]]; then
   exit 0
fi

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# Download QuantumESPRESSO installer into tempdir and unpack it into the apps directory
if [[ ! -s ${HOMEDIR}/apps/${QE_DL_VER}  ]]; then
#空の場合の処理
   rm ${HOMEDIR}/apps/${QE_DL_VER} | exit 0
   if [[ ! -f ${HOMEDIR}/apps/${QE_DL_VER} ]]; then
      wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/${QE_DL_VER}
      chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism
   fi
   if [[ ! -d ${HOMEDIR}/apps/qe-6.1-rism ]]; then
      tar zxfp ${HOMEDIR}/apps/${QE_DL_VER} -C ${HOMEDIR}/apps
      chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism
   fi
else
# 0byte 以上の処理
   if [[ ! -f ${HOMEDIR}/apps/${QE_DL_VER} ]]; then
      wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/${QE_DL_VER}
      chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism
   fi
   if [[ ! -d ${HOMEDIR}/apps/qe-6.1-rism ]]; then
      tar zxfp ${HOMEDIR}/apps/${QE_DL_VER} -C ${HOMEDIR}/apps
      chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism
   fi
fi

#clean up
popd
rm -rf $tmpdir


echo "end of 30.download-${SW}.sh"
