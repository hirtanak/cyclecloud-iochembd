#!/bin/bash
# Copyright (c) 2019-2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=qe
echo "starting 20.execute-${SW}.sh"

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
QE_DL_URL=https://github.com/QEF/q-e/releases/download/qe-${QE_VERSION}/qe-${QE_VERSION}-ReleasePack.tgz
QE_DL_URL2=https://github.com/QEF/q-e/releases/download/qe-${QE_VERSION}/qe-${QE_VERSION}_release_pack.tgz
QE_DIR=qe-${QE_VERSION}

if [[ ${QE_VERSION} = None ]]; then 
    exit 0 
fi

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# Don't run if we've already expanded the QuantumESPRESSO tarball. Download QuantumESPRESSO installer into tempdir and unpack it into the apps directory
if [[ ! -f ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz ]] || [[ ! -f ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz ]] ; then
    wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || wget -nv ${QE_DL_URL2} -O ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
    chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
fi
if [[ -f ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz ]] || [[ -f ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz ]]; then
    if [[ ! -s ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz ]] || [[ ! -s ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz ]]; then
    #空の場合の処理
        echo "qe-${QE_VERSION}-ReleasePack.tgz is 0byte"
	rm ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || rm ${HOMEDIR}/apps/qe-${QE_VERSION2}_release_pack.tgz
        wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || wget -nv ${QE_DL_URL2} -O ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
        chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
    else
    # 0byte 以上の処理
        chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
        tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz -C ${HOMEDIR}/apps || tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz -C ${HOMEDIR}/apps
    fi
fi
if [[ ! -d ${HOMEDIR}/apps/${QE_DIR} ]]; then
    tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz -C ${HOMEDIR}/apps || tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz -C ${HOMEDIR}/apps
fi
CMD=$(ls -la ${HOMEDIR}/apps/ | grep ${QE_DIR} | awk '{print $3}'| head -1)
if [[ -z ${CMD} ]]; then
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DIR} | exit 0
fi

#clean up
popd
rm -rf $tmpdir


echo "end of 20.download-${SW}.sh"
