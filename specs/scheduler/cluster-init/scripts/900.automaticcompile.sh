#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

echo "starting 900.automaticcompile.sh"

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

# get Quantum ESPRESSO vers
AUTOMATIC_COMPILE=$(jetpack config AUTOMATIC_COMPILE)

# GPU compile setting
GROMACS_GPU_COMPILE=$(jetpack config GROMACS_GPU_COMPILE)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

if [[ ${AUTOMATIC_COMPILE} = "True" ]]; then
#   echo "sleep 180" > ${HOMEDIR}/sleep.sh
#   chown ${CUSER}:${CUSER} ${HOMEDIR}/sleep.sh
#   sudo -u ${CUSER} /opt/pbs/bin/qsub -l select=1:ncpus=44 ${HOMEDIR}/sleep.sh
   echo "#!/usr/bin/bash" > ${HOMEDIR}/sleep.sh
   echo "#SBATCH --cpus-per-task=1" >> ${HOMEDIR}/sleep.sh
   echo "#SBATCH --nodes=1" >> ${HOMEDIR}/sleep.sh
   echo "sleep 300" >> ${HOMEDIR}/sleep.sh
   chown ${CUSER}:${CUSER} ${HOMEDIR}/sleep.sh
   if [[ ${GROMACS_GPU_COMPILE} = "False" ]]; then
       sudo -u ${CUSER} /usr/bin/sbatch -N 1 -t 120 ${HOMEDIR}/sleep.sh
   fi
   if [[ ${GROMACS_GPU_COMPILE} = "True" ]]; then
       sudo -u ${CUSER} /usr/bin/sbatch -p htc -N 1 -t 120 ${HOMEDIR}/sleep.sh
   fi
fi

# file settings
if [[ ! -d ${HOMEDIR}/logs ]]; then
   mkdir -p ${HOMEDIR}/logs
   chown -R ${CUSER}:${CUSER} ${HOMEDIR}/logs
fi
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps 
cp /opt/cycle/jetpack/logs/cluster-init/ioChem-BD/scheduler/scripts/900.automaticcompile.sh.out ${HOMEDIR}/logs/
chown ${CUSER}:${CUSER} ${HOMEDIR}/logs/900.automaticcompile.sh.out

#clean up
popd
rm -rf $tmpdir


echo "end of 900.automaticcompile.sh"
