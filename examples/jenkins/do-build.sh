#!/bin/bash

export JEN_BUILD_TYPE=verify
export JEN_CLEANUP=0
export JEN_VIRL_SERVER=virl.example.com


export JEN_SRC_DIR=${PWD}
export JEN_BUILD_DIR=${PWD}/build
if [ "${JEN_BUILD_TYPE}" = "merge" ]; then
	# A merge build always starts from scratch
	rm -rf ${JEN_BUILD_DIR}
fi
mkdir -p ${JEN_BUILD_DIR} && cd ${JEN_BUILD_DIR}

# ===================================================================================
# Choose one of these if needed. These are different from the TSOCKS variables below.
# These are used to connect the simulated hosts back to the Jenkins server.
#export JEN_SOCKS_PROXY=localhost:1080
# Use this to deploy tsocks on remote hosts
#export JEN_REMOTE_SOCKS_SRC=http://myserver.example.com/debian-pkgs/tsocks_1.8beta5-9.2_amd64.deb
export JEN_HTTP_PROXY=localhost:3128
export HTTP_PROXY="http://${JEN_HTTP_PROXY}/"
export HTTPS_PROXY="http://${JEN_HTTP_PROXY}/"
export http_proxy="http://${JEN_HTTP_PROXY}/"
export https_proxy="http://${JEN_HTTP_PROXY}/"
export no_proxy="localhost,127.0.0.1,proxy.example.com,proxy"
# ===================================================================================

# ===================================================================================
# These are different from the choice abive. These are used to connect Jenkins to the VIRL server.
#export TSOCKS_CONF_FILE="${JEN_BUILD_DIR}/tsocks.conf"
#export TSOCKS_DEBUG=9
#export JEN_LD_PRELOAD=/usr/lib64/libtsocks.so
# Connect to a VIRL server over SOCKS
#cat >${TSOCKS_CONF_FILE} << _EOF_
#server = 127.0.0.1
#server_port = 1080
#_EOF_
# ===================================================================================

# Used by the VIRL-CORE API
export VIRL_STD_URL="http://${JEN_VIRL_SERVER}:19399/"
export VIRL_UWM_URL="http://${JEN_VIRL_SERVER}:19400/"

# Let's assume the VIRL topology is inside the source code we're testing with this Jenkins build
export JEN_VIRL_FILE_IN=${JEN_SRC_DIR}/topology/jenkins-${JEN_BUILD_TYPE}.virl
export JEN_VIRL_FILE_OUT=${JEN_BUILD_DIR}/jenkins.virl.out

# Didn't want to put these on a webserver
export JEN_SSH_KEYFILE=${HOME}/.ssh/jenkins_slave.pem
export JEN_SSH_PUBKEYFILE="${JEN_SSH_KEYFILE}.pub"

# A custom IOS image that the ODL server will talk to and that may not yet be present on VIRL
export JEN_IOSXRV_SRC=http://myserver.example.com/images/5.1.1.53U.vmdk

# A custum ubuntu image containing the result of installing the prereqs during
# a merge build. We use this in verify builds.
export JEN_VRFY_SRC="http://myserver.example.com/images/ubuntu-trusty64-integration-java+python-1.0.img"

# The example here is a client that talks to a Cisco ODL server which we'll need to install in
# one of the virtual machines we'll be running inside VIRL.
export JEN_KARAF_SRC=http://myserver.example.com/images/distribution-karaf-1.0.0-00003.tar.gz

# The code we're testing here with jenkins
export JEN_GIT_SRC=http://github.com/me/my-code

# The compiled VIRL libraries we'll be using to interface with VIRL
JEN_VIRLWHEEL_SRC=http://myserver.example.com/python-pkgs/VIRL_CORE-0.10.13.11-py2-none-any.bin.whl
export JEN_VIRLWHEEL_FILE=`basename $JEN_VIRLWHEEL_SRC`

# The scripts that we'll download to do the actual work
export JEN_PREPARE_SRC=http://myserver.example.com/jenkins/prepare-virl.sh
export JEN_PREPARE_FILE=`basename $JEN_PREPARE_SRC`
export JEN_STARTVIRL_SRC=http://myserver.example.com/jenkins/start-virl.sh
export JEN_STARTVIRL_FILE=`basename $JEN_STARTVIRL_SRC`
export JEN_ODLSETUP_SRC=http://myserver.example.com/jenkins/odl-setup.sh
export JEN_ODLSETUP_FILE=`basename $JEN_ODLSETUP_SRC`
export JEN_COSC_SETUP_SRC=http://myserver.example.com/jenkins/cosc-setup.sh
export JEN_COSC_SETUP_FILE=`basename $JEN_COSC_SETUP_SRC`

# ===================================================================================
# Setup ssh agent
if [ ! -f ssh-agent.sh ]; then
    ssh-agent > ./ssh-agent.sh
fi
chmod +x ./ssh-agent.sh
. ./ssh-agent.sh
ssh-add $JEN_SSH_KEYFILE
# ===================================================================================

SKIP_FULL=0
# If our simulation is gone or we're missing binaries, then force a full install and simulation startup
if [ "$JEN_BUILD_TYPE" = "verify" -a -s simulation_id ]; then
    export JEN_SIMULATION=`cat simulation_id`
    if which virl_std_client 2>/dev/null; then  # VIRL-CORE API present?
        if which virl-dictval 2>/dev/null; then # virl-utils present?
            while ! env VIRL_STD_USER_NAME=guest VIRL_STD_PASSWORD=guest virl_std_client simengine-status -s $JEN_SIMULATION >status-before; do
                sleep 1
            done
            if [ "`virl-dictval -f status-before state`" = "ACTIVE" ]; then
                SKIP_FULL=1
            fi
        fi
    fi
fi

if [ $SKIP_FULL -eq 0 ]; then
    unset JEN_SIMULATION
    rm -f simulation_id
fi

if [ "$JEN_BUILD_TYPE" = "merge" -o ! -s simulation_id ]; then
    rm -f $JEN_PREPARE_FILE $JEN_STARTVIRL_FILE $JEN_VIRLWHEEL_FILE $JEN_VIRLUTILS_FILE
    LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_PREPARE_SRC}
    LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_STARTVIRL_SRC}
    LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_VIRLWHEEL_SRC}


    if [ `pip list | grep VIRL-CORE | wc -l` -gt 0 ]; then
        pip uninstall -y VIRL_CORE
    fi
    # I develop virl-utils, so I wanna make sure I get the latest version on each run
    if [ `pip list | grep virl-utils | wc -l` -gt 0 ]; then
        pip uninstall -y virl-utils
    fi
    LD_PRELOAD="$JEN_LD_PRELOAD" pip install ${JEN_VIRLWHEEL_FILE} lxml pexpect virl-utils
    bash $JEN_PREPARE_FILE
    bash $JEN_STARTVIRL_FILE
fi

rm -f $JEN_ODLSETUP_FILE
LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_ODLSETUP_SRC}
bash $JEN_ODLSETUP_FILE

pip install lxml requests ipaddress tornado pyzmq virl-utils

rm -f $JEN_COSC_SETUP_FILE
LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_COSC_SETUP_SRC}
bash $JEN_COSC_SETUP_FILE

# Do some cleanup, unless we want to keep around the VIRL simulation for our next run
if [ ${JEN_CLEANUP} -eq 1 ]; then
    JEN_SIMULATION=`cat simulation_id`
    if [ -n "$JEN_SIMULATION" ]; then
        env VIRL_STD_USER_NAME=guest VIRL_STD_PASSWORD=guest virl_std_client simengine-status -s $JEN_SIMULATION >status-after
        if [ "`virl-dictval -f status-after state`" = "ACTIVE" ]; then
            env VIRL_STD_USER_NAME=guest VIRL_STD_PASSWORD=guest virl_std_client simengine-stop -s $JEN_SIMULATION
        fi
    fi
fi

