#!/bin/bash
# Copyright (c) 2019-2000 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=qe
echo "starting 20.execute-install-${SW}.sh"

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

# Azure VMs that have ephemeral storage mounted at /mnt/exports.
if [ ! -d ${HOMEDIR}/apps ]; then
    sudo -u ${CUSER} ln -s /mnt/exports/apps ${HOMEDIR}/apps
    chown ${CUSER}:${CUSER} /mnt/exports/apps
fi
chown ${CUSER}:${CUSER} /mnt/exports/apps | exit 0

# install packages
yum install -y openssl-devel libgcrypt-devel
yum remove -y cmake gcc


# build setting
alias gcc=/opt/gcc-9.2.0/bin/gcc
alias c++=/opt/gcc-9.2.0/bin/c++
# PATH settings
export PATH=/opt/gcc-9.2.0/bin/:$PATH
# need "set +/-" setting for parameter proceesing
declare OPENMPI_PATH
declare LD_LIBRARY_PATH
OPENMPI_PATH=$(ls /opt/ | grep openmpi)
export PATH=/opt/${OPENMPI_PATH}/bin:$PATH
set +u
export LD_LIBRARY_PATH=/opt/gcc-9.2.0/lib64:$LD_LIBRARY_PATH
set -u

# Don't run if we've already expanded the QuantumESPRESSO file.
if [[ ! -f ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz ]] ||  [[ ! -f ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz ]]; then
    wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || wget -nv ${QE_DL_URL2} -O ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
    chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz || chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz
fi
if [[ ! -d ${HOMEDIR}/apps/${QE_DIR} ]]; then
    tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}-ReleasePack.tgz -C ${HOMEDIR}/apps || tar zxfp ${HOMEDIR}/apps/qe-${QE_VERSION}_release_pack.tgz -C ${HOMEDIR}/apps
fi
declare CMD
CMD=$(ls -la ${HOMEDIR}/apps/ | grep ${QE_DIR} | awk '{print $3}'| head -1)
if [[ -z ${CMD} ]]; then
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DIR} | exit 0
fi

# build and install
if [[ ! -f ${HOMEDIR}/apps/${QE_DIR}/bin/pw.x ]]; then 
    make clean all | exit 0 
    ${HOMEDIR}/apps/${QE_DIR}/configure --with-internal-blas --with-internal-lapack
    chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DIR}/make.inc | exit 0
    cd ${HOMEDIR}/apps/${QE_DIR}
    CORES=$(($(grep cpu.cores /proc/cpuinfo | wc -l) + 1))
    make all -j ${CORES}
fi
declare CMD2
set +u
CMD2=$(grep ${QE_DIR} ${HOMEDIR}/.bashrc | head -1) | exit 0
if [[ -n ${CMD2} ]]; then
    (echo "export PATH=${HOMEDIR}/apps/${QE_DIR}/bin:$PATH") >> ${HOMEDIR}/.bashrc
fi
set -u

# file settings
if [[ ! -d ${HOMEDIR}/logs ]]; then
   mkdir -p ${HOMEDIR}/logs
   chown -R ${CUSER}:${CUSER} ${HOMEDIR}/logs
fi
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/logs/
cp /opt/cycle/jetpack/logs/cluster-init/ioChem-BD/execute/scripts/20.execute-install-${SW}.sh.out ${HOMEDIR}/logs/
chown ${CUSER}:${CUSER} ${HOMEDIR}/logs/20.execute-install-${SW}.sh.out

#clean up
popd
rm -rf $tmpdir


echo "end of 20.execute-install-${SW}.sh"
