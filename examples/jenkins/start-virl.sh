#!/bin/bash


JEN_GIT_FILE=`basename $JEN_GIT_SRC`
if [ -n "${JEN_REMOTE_SOCKS_SRC}" ]; then
	JEN_REMOTE_SOCKS_FILE=`basename $JEN_REMOTE_SOCKS_SRC`
fi

if [ -n "$JEN_REMOTE_SOCKS_FILE" -a ! -f "$JEN_REMOTE_SOCKS_FILE" ]; then
	LD_PRELOAD="$JEN_LD_PRELOAD" wget ${JEN_REMOTE_SOCKS_FILE}
fi

export LD_PRELOAD="$JEN_LD_PRELOAD"

export VIRL_STD_USER_NAME=${JEN_VIRL_STD_NAME:="guest"}
export VIRL_STD_PASSWORD=${JEN_VIRL_STD_PASSWORD:="guest"}

set | grep ^JEN > environment1
set | grep ^PATH >> environment1
set | grep ^PYTHONPATH >> environment1
set | grep ^VIRL >> environment1
set | grep ^TSOCK >> environment1
set | grep ^LD_PRELOAD >> environment1
cat environment1  | sed -e 's/^\(..*\)$/export \1/' > environment1.sh

JEN_SIMULATION=`virl_std_client simengine-launch -f ${JEN_VIRL_FILE_IN} | awk '{print $4}'`
if [ $? -gt 0 -o -z "$JEN_SIMULATION" ]; then
	echo 'Failed...' >&2
	exit 2
fi
export JEN_SIMULATION
echo JEN_SIMULATION=${JEN_SIMULATION}
echo export JEN_SIMULATION=${JEN_SIMULATION} >> environment1.sh

# Wait for simulation to become active
while [ "$(virl_std_client simengine-status -s $JEN_SIMULATION | virl-dictval state)" != 'ACTIVE' ]; do
	sleep 5
done

virl_std_client simengine-export -u -s ${JEN_SIMULATION} > ${JEN_VIRL_FILE_OUT}

# Wait for nodes to become active
JEN_SERVERS=`virl-nodes -s 'server' < ${JEN_VIRL_FILE_OUT}`
JEN_IOSV=`virl-nodes -s 'IOSv' < ${JEN_VIRL_FILE_OUT}`
JEN_IOSXRV=`virl-nodes -s 'IOS XRv' < ${JEN_VIRL_FILE_OUT}`
JEN_ROUTERS="$JEN_IOSV $JEN_IOSXRV"
JEN_NODES="$JEN_SERVERS $JEN_ROUTERS"
JEN_NODE_COUNT=`echo $JEN_NODES | wc -w`
JEN_LIVE_COUNT=0
while [ $JEN_LIVE_COUNT -lt $JEN_NODE_COUNT ]; do
	JEN_LIVE_COUNT=`virl_std_client simengine-serial-port -s $JEN_SIMULATION -m telnet --port-id 0 -n $JEN_NODES 2>/dev/null | virl-ports | wc -l`
done
echo "My servers are:"
virl_std_client simengine-serial-port -s $JEN_SIMULATION -m telnet --port-id 0 -n $JEN_SERVERS 2>/dev/null | virl-ports
echo "My routers are:"
virl_std_client simengine-serial-port -s $JEN_SIMULATION -m telnet --port-id 0 -n $JEN_ROUTERS 2>/dev/null | virl-ports

# Re-export the updated virl file, it should have the values we need now.
virl_std_client simengine-export -u -s ${JEN_SIMULATION} > ${JEN_VIRL_FILE_OUT}

# Wait patiently for IOS XRv to come up
virl_std_client simengine-serial-port -s $JEN_SIMULATION -m telnet --port-id 0 -n $JEN_IOSXRV 2>/dev/null | virl-ports | while read node host port; do
	echo virl-ios-wait -d -s ${host} -p ${port} -t 1000 '".*%MGBL-CVAC-4-CONFIG_DONE.*"' '".*%MGBL-CVAC-4-CONFIG_DONE.*"'
done | mfork

if [ -n "$JEN_SOCKS_PROXY" ]; then
	JEN_SSH_OPT="RemoteForward 1080 $JEN_SOCKS_PROXY"
elif [ -n "$JEN_HTTP_PROXY" ]; then
	JEN_SSH_OPT="RemoteForward 3128 $JEN_HTTP_PROXY"
fi

virl-mk-ssh-config  -i ${JEN_SSH_KEYFILE}  -f ${JEN_VIRL_FILE_OUT} -s ${JEN_VIRL_SERVER} -o "$JEN_SSH_OPT" > ssh_config
echo SSH config is:
cat ssh_config

for f in `virl-nodes -s 'IOS XRv' < ${JEN_VIRL_FILE_OUT} | grep ios`; do
	IPADDR=`virl-node-val -n $f AutoNetkit.mgmt_ip < ${JEN_VIRL_FILE_OUT}`
	virl-ios-login-chat -d -c "ssh -F ssh_config ${JEN_VIRL_SERVER}" -s $IPADDR "[a-zA-Z0-9/:]*${f}[#>]" 'crypto key generate dsa' '.*\[1024\].*|% You already' 'no' "\[OK\]|[a-zA-Z0-9/:]*${f}[#>]"
done

if [ "${JEN_BUILD_TYPE}" = "merge" ]; then
	# This will be run remotely as root
	cat >runasroot1.sh <<_EOF_
#!/bin/bash
echo 'Dpkg::Progress-Fancy "0";' > /etc/apt/apt.conf.d/91progress
echo 'export DEBIAN_FRONTEND=noninteractive' > /etc/profile.d/headless.sh
_EOF_

	# Socks proxy
	if [ -n "$JEN_SOCKS_PROXY" ]; then
		cat >>runasroot1.sh <<_EOF_
#!/bin/bash
echo 'Acquire::socks::proxy "socks://127.0.0.1:1080/";' > /etc/apt/apt.conf.d/90proxy
cat >/etc/tsocks.conf <<@EOF@
server = 127.0.0.1
server_port = 1080
@EOF@
cat >/etc/proxy.sh <<@EOF@
export LD_PRELOAD=/usr/lib/libtsocks.so
export TSOCKS_CONF_FILE=/etc/tsocks.conf
@EOF@
_EOF_

	# If we are using a proxy, set it up
	elif [ -n "$JEN_HTTP_PROXY" ]; then
		JEN_REMOTE_HTTP_PROXY="http://localhost:3128/"
		cat >>runasroot1.sh <<_EOF_
#!/bin/bash
echo 'Acquire::http::proxy "http://localhost:3128/";' > /etc/apt/apt.conf.d/90proxy
cat >/etc/proxy.sh <<@EOF@
export HTTP_PROXY=${JEN_REMOTE_HTTP_PROXY}
export HTTPS_PROXY=${JEN_REMOTE_HTTP_PROXY}
export http_proxy=${JEN_REMOTE_HTTP_PROXY}
export https_proxy=${JEN_REMOTE_HTTP_PROXY}
export no_proxy=127.0.0.1,localhost,localhost.localdomain
@EOF@
_EOF_
	fi
	chmod +x ./runasroot1.sh
	for f in `virl-nodes -s 'server' < ${JEN_VIRL_FILE_OUT}`; do
		FIXROOT=`which virl-fixroot.sh`
		scp -F ssh_config ${FIXROOT} $f:virl-fixroot.sh
		# We need to clobber .bashrc on purpose. The reason is that
		# ubuntu by default exist from .bashrc when running non-interactive
		ssh -F ssh_config $f 'echo "export PASSWORD=cisco" > ~/.bashrc'
		ssh -F ssh_config $f 'echo "export SUDO_ASKPASS=${HOME}/bin/askpass" >> ~/.bashrc'
		ssh -F ssh_config $f ./virl-fixroot.sh
		if [ -n "${JEN_REMOTE_SOCKS_FILE}" ]; then
			scp -F ssh_config ${JEN_REMOTE_SOCKS_FILE} root@$f:
			ssh -F ssh_config root@$f dpkg -i ${JEN_REMOTE_SOCKS_FILE}
		fi
		scp -F ssh_config runasroot1.sh root@$f:
		ssh -F ssh_config root@$f ./runasroot1.sh
	done

	# Setup karaf prereqs
	cat > runasroot2.sh <<_EOF_
#!/bin/bash
test -s /etc/proxy.sh && source /etc/proxy.sh
apt-get update
#apt-get install -y openjdk-7-jdk
apt-get install -y openjdk-7-jre-headless
rm -rf $JEN_GIT_FILE
git clone $JEN_GIT_SRC
cat >/etc/profile.d/java.sh <<@EOF@
export JAVA_HOME=\$(readlink -f /usr/bin/java | sed "s:bin/java::")
@EOF@
_EOF_
	chmod +x ./runasroot2.sh

	for f in `virl-nodes -s 'server' < ${JEN_VIRL_FILE_OUT}`; do
		echo "scp -F ssh_config runasroot2.sh root@${f}: ; ssh -F ssh_config root@$f ./runasroot2.sh"
	done | mfork

	# Perform the reboots all at once to increase our chances of seeing the coud init msg
	for f in `virl-nodes -s 'server' < ${JEN_VIRL_FILE_OUT}`; do
		echo "ssh -F ssh_config root@${f} init 6"
	done | mfork

	# Wait for reboot to finish
	virl_std_client simengine-serial-port -s $JEN_SIMULATION -m telnet --port-id 0 -n $JEN_SERVERS 2>/dev/null | virl-ports | while read node host port; do 
		echo virl-ios-wait -s ${host} -p ${port} -t 1000 "'Cloud-init .* finished'"
	done | mfork
fi

echo $JEN_SIMULATION > simulation_id
