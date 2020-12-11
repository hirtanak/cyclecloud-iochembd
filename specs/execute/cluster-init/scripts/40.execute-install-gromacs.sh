#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=gromacs
echo "starting 40.install-${SW}.sh"

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

# get GROMACS version
GROMACS_VERSION=$(jetpack config GROMACS_VERSION)
if [[ ${GROMACS_VERSION} = None ]]; then
    exit 0
fi
GROMACS_GPU_COMPILE=$(jetpack config GROMACS_GPU_COMPILE)

CMAKE_VERSION=3.16.4

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

yum install -y openssl-devel libgcrypt-devel
yum remove -y cmake gcc

# build setting
#alias gcc=/opt/gcc-9.2.0/bin/gcc
#alias c++=/opt/gcc-9.2.0/bin/c++
# PATH settings
#export PATH=/opt/gcc-9.2.0/bin/:$PATH
export PATH=${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin:$PATH
# need "set +/-" setting for parameter proceesing
set +u
OPENMPI_PATH=$(ls /opt/ | grep openmpi)
export PATH=/opt/${OPENMPI_PATH}/bin:$PATH
#export LD_LIBRARY_PATH=/opt/gcc-9.2.0/lib64:$LD_LIBRARY_PATH
CMD=$(grep "cmake" ${HOMEDIR}/.bashrc | head -1)
if [[ -z ${CMD} ]]; then
    CMD1=$(grep '^export PATH' ${HOMEDIR}/.bashrc | head -1)
    CMD2=${CMD1#export PATH=}
    #echo $CMD2
    if [[ -n ${CMD2} ]]; then
        sed -i -e "s!^export PATH!export PATH=${HOMEDIR}\/apps\/cmake-${CMAKE_VERSION}-Linux-x86_64\/bin:${CMD2}!g" ${HOMEDIR}/.bashrc
    fi
    if [[ -z ${CMD2} ]]; then 
        (echo "export PATH=${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin:$PATH") >> ${HOMEDIR}/.bashrc
    fi
fi
# getting compile setting
VMSKU=`cat /proc/cpuinfo | grep "model name" | head -1 | awk '{print $7}'`
CORES=$(grep cpu.cores /proc/cpuinfo | wc -l) 
unset PLATFORM
case "$CORES" in
    "2"   ) PLATFORM=$(echo "-DGMX_SIMD=AVX_512") ;;
    "4"   ) PLATFORM=$(echo "-DGMX_SIMD=AVX_512") ;;
    "8"   ) PLATFORM=$(echo "-DGMX_SIMD=AVX_512") ;;
    "44"  ) PLATFORM=$(echo "-DGMX_SIMD=AVX_512") ;;
    "60"  ) ;;
    "120" ) ;;
esac
echo $PLATFORM
# need "set +" setting for parameter proceesing
set -u

# gromacs build and install
echo ${GROMACS_GPU_COMPILE}
case ${GROMACS_GPU_COMPILE} in 
    # cpu compile
    Flase )
    # Addtional build settings
    alias gcc=/opt/gcc-9.2.0/bin/gcc
    alias c++=/opt/gcc-9.2.0/bin/c++
    # PATH settings
    export PATH=/opt/gcc-9.2.0/bin/:$PATH
    export LD_LIBRARY_PATH=/opt/gcc-9.2.0/lib64:$LD_LIBRARY_PATH
    # check build or not
    if [[ ! -d ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/bin ]]; then 
        rm -rf ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build && mkdir -p ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build
        chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build
        # check cmake version
        if [[ -f ${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin/cmake ]]; then
            # due to parameter proceecing
            set +u
            cd ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build && sudo -u ${CUSER} ${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin/cmake ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION} -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON -DCMAKE_C_COMPILER="/opt/${OPENMPI_PATH}/bin/mpicc" -DCMAKE_CXX_COMPILER="/opt/${OPENMPI_PATH}/bin/mpicxx" -DCMAKE_INSTALL_PREFIX="${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}" ${PLATFORM} -DGMX_MPI=ON
            make -j ${CORES}
            make install 
            chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}
            set -u
        fi
    fi
    ;;
    # GPU compile
    True )
    # CUDA version settings
    #CUDA_VERSION=$(jetpack config CUDA_VERSION)
    CUDA_VERSION=10.0
    CUDA_BUILD=130 # 10.0:130, 10.1:243, 10.2:89
    # set up NVIDIA driver and compute nodes
    set +u
    unset CMD && CMD=$(cat /proc/driver/nvidia/version | head -1 | awk '{print $3}') | exit 0
    if [[ -z ${CMD} ]]; then
        echo "download and install NVIDIA Driver"
        yum install -y dkms make kernel-devel-$(uname -r) kernel-headers-$(uname -r)
	CUDA_URL=https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-${CUDA_VERSION}.${CUDA_BUILD}-1.x86_64.rpm
	wget -nv ${CUDA_URL} -O ${HOMEDIR}/apps/${CUDA_URL##*/}
        chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${CUDA_URL##*/}
        rpm -i ${HOMEDIR}/apps/${CUDA_URL##*/} | exit 0
        yum clean all
        yum install -y cuda-${CUDA_VERSION/./-}
    else
        echo "skipping install NVIDIA Driver"
    fi
    set -u
    # build GPU
    if [[ ! -d ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/bin ]]; then
	set +u
        rm -rf ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build | exit 0 && mkdir -p ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build
        chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build
        # check cmake version
        if [[ -f ${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin/cmake ]]; then 
            unset CMD && CMD=$(lspci | grep NVIDIA) | exit 0
            if [[ ! -s ${CMD} ]]; then
                # due to parameter proceecing
                set +u
                export PATH=$(echo -n $PATH |tr ':' '\n' |sed '/opt\/gcc-9.2.0\/bin/d' |tr '\n' ':')
                export LD_LIBRARY_PATH=$(echo -n $LD_LIBRARY_PATH |tr ':' '\n' |sed '/opt\/gcc-9.2.0\/lib64/d' |tr '\n' ':')
                yum install -y centos-release-scl
                yum install -y devtoolset-7
                scl enable devtoolset-7 bash
                export PATH=/opt/rh/devtoolset-7/root/bin:$PATH
                export LD_LIBRARY_PATH=/opt/rh/devtoolset-7/root/lib64:$LD_LIBRARY_PATH
                # build gpy settings
                cd ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/build && ${HOMEDIR}/apps/cmake-${CMAKE_VERSION}-Linux-x86_64/bin/cmake ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION} -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON -DCMAKE_C_COMPILER="/opt/${OPENMPI_PATH}/bin/mpicc" -DCMAKE_CXX_COMPILER="/opt/${OPENMPI_PATH}/bin/mpicxx" -DCMAKE_INSTALL_PREFIX="${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}" ${PLATFORM} -DGMX_MPI=ON -DGMX_GPU=ON -DGMX_DOUBLE=OFF
                make -j ${CORES}
                make install
                chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/gromacs-${GROMACS_VERSION}
                # process after build
                set -u
                yum remove -y cmake gcc centos-release-scl devtoolset-7
                export PATH=$(echo -n $PATH |tr ':' '\n' |sed '/opt\/rh\/devtoolset-7\/root\/bin/d' |tr '\n' ':')
                export PATH=$(echo -n $LD_LIBRARY_PATH |tr ':' '\n' |sed '/opt\/rh\/devtoolset-7\/root\/lib64/d' |tr '\n' ':')
            fi
        fi
    fi
    ;;
esac

# gromacs ui setting
(echo "source {HOMEDIR}/apps/gromacs-${GROMACS_VERSION}/bin/GMXRC") > /etc/profile.d/gmx.sh
chmod a+x /etc/profile.d/gmx.sh
chown ${CUSER}:${CUSER} /etc/profile.d/gmx.sh

# log file settings
if [[ ! -d ${HOMEDIR}/logs ]]; then
    mkdir -p ${HOMEDIR}/logs
    chown -R ${CUSER}:${CUSER} ${HOMEDIR}/logs
fi
cp /opt/cycle/jetpack/logs/cluster-init/ioChem-BD/execute/scripts/40.execute-install-${SW}.sh.out ${HOMEDIR}/logs/
chown ${CUSER}:${CUSER} ${HOMEDIR}/logs/40.execute-install-${SW}.sh.out

#clean up
popd
rm -rf $tmpdir


echo "end of 40.install-${SW}.sh"
