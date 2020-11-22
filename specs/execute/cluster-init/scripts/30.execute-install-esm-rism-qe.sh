#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=esm-rism-qe
echo "starting 30.execute-install-${SW}.sh"

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

# get Quantum ESPRESSO version
if [[ ${QE_DL_URL} = None ]]; then
   exit 0
fi

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# install packages
yum install -y openssl-devel libgcrypt-devel
yum remove -y cmake gcc

# build setting
# need "set +" setting for parameter proceesing
set +u
alias gcc=/opt/gcc-9.2.0/bin/gcc
alias c++=/opt/gcc-9.2.0/bin/c++
# PATH settings
export PATH=/opt/gcc-9.2.0/bin/:$PATH
#export PATH=/opt/openmpi-4.0.2/bin:$PATH
# get current openmpi version
OPENMPI_VERSION=$(ls /opt/ | grep openmpi-*)
export PATH=/opt/openmpi-${OPENMPI_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-9.2.0/lib64:$LD_LIBRARY_PATH
set -u

# License File Setting
LICENSE=$(jetpack config LICENSE)
(echo "export LICENSE_FILE=${LICENSE}") > /etc/profile.d/rism-qe.sh
chmod a+x /etc/profile.d/rism-qe.sh
chown ${CUSER}:${CUSER} /etc/profile.d/rism-qe.sh


# download ESM RISM QuantumESPRESOO
if [[ ! -f ${HOMEDIR}/apps/${QE_DL_VER} ]]; then
   wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/${QE_DL_VER}
   chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DL_VER}
fi
if [[ ! -d ${HOMEDIR}/apps/qe-6.1-rism ]]; then
   tar zxfp ${HOMEDIR}/apps/qe-6.1-rism -C ${HOMEDIR}/apps
   chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism
fi

# build and install
if [[ ! -f ${HOMEDIR}/apps/qe-6.1-rism/bin/pw.x ]]; then 
   alias gcc=/opt/gcc-9.2.0/bin/gcc
   export PATH=/opt/gcc-9.2.0/bin:$PATH
   make clean all | exit 0 
   ${HOMEDIR}/apps/qe-6.1-rism/configure --with-internal-blas --with-internal-lapack
   chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism/make.inc | exit 0
   #CORES=$(($(grep cpu.cores /proc/cpuinfo | wc -l) + 1))
   cd ${HOMEDIR}/apps/qe-6.1-rism && make all #${CORES}
fi

# need set +u setting for parameter prcessing
set +u
CMD=$(ls -la ${HOMEDIR}/apps/ | grep "qe-6.1-rism" | awk '{print $3}'| head -1) | exit 0
if [[ -z ${CMD} ]]; then
    (echo "export PATH=${HOMEDIR}/apps/qe-6.1-rism/bin:$PATH") >> ${HOMEDIR}/.bashrc
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/qe-6.1-rism | exit 0
fi
chmod -R 755 ${HOMEDIR}/apps/qe-6.1-rism | exit 0
# need set +u setting for parameter prcessing
set -u

# file settings
if [[ ! -d ${HOMEDIR}/logs ]]; then
   mkdir -p ${HOMEDIR}/logs
   chown -R ${CUSER}:${CUSER} ${HOMEDIR}/logs
fi
#chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps 
cp /opt/cycle/jetpack/logs/cluster-init/ioChem-BD/execute/scripts/30.execute-install-${SW}.sh.out ${HOMEDIR}/logs/
chown ${CUSER}:${CUSER} ${HOMEDIR}/logs/30.execute-install-${SW}.sh.out

#clean up
popd
rm -rf $tmpdir


echo "end of 30.execute-install-${SW}.sh"
