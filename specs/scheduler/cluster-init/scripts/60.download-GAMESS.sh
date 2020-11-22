#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=GAMESS
echo "starting 60.download-${SW}.sh"

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
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ioChem-BD/master

# get Quantum ESPRESSO version
GAMESS_FILENAME=$(jetpack config GAMESS_FILENAME)
#GAMESS_CONFIG=https://raw.githubusercontent.com/hirtanak/cyclecloud-QCMD/master/specs/master/cluster-init/files/gemessconfig00
#GAMESS_DL_URL=https://www.msg.chem.iastate.edu/GAMESS/download/dist.source.shtml
#GAMESS_DL_PASSWORD=$(jetpack config GAMESS_DOWNLOAD_PASSWORD)
GAMESS_BUILD=$(jetpack config GAMESS_BUILD)
GAMESS_DIR=${HOMEDIR}/apps/${GAMESS_BUILD}
AUTOMATIC_COMPILE=$(jetpack config AUTOMATIC_COMPILE)
CORES=$(grep cpu.cores /proc/cpuinfo | wc -l)

# get GAMESS version
if [[ ${GAMESS_BUILD} = None ]]; then
   exit 0
fi


# Don't run if we've already expanded the GAMESS tarball. Download GAMESS
if [[ ! -f ${HOMEDIR}/apps/${GAMESS_FILENAME} ]]; then
   jetpack download ${GAMESS_FILENAME} ${HOMEDIR}/apps/
   chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${GAMESS_FILENAME}
fi

if [[ ! -d ${GAMESS_DIR} ]]; then
   tar zxfp ${HOMEDIR}/apps/${GAMESS_FILENAME} -C ${HOMEDIR}/apps/
   mv ${HOMEDIR}/apps/gamess ${GAMESS_DIR}
   chown -R ${CUSER}:${CUSER} ${GAMESS_DIR}
fi


echo "end of 60.download-${SW}.sh"
