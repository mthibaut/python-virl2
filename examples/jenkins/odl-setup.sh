#!/bin/sh

JEN_KARAF_FILE=`basename $JEN_KARAF_SRC`
JEN_KARAF_DIR=`echo $JEN_KARAF_FILE | sed -e 's/\.tar\.gz//'`

cat > run-odl-install.sh <<_EOF_
#!/bin/bash -vx
if [ -s /etc/proxy.sh ]; then 
	. /etc/proxy.sh
fi
if [ "${JEN_BUILD_TYPE}" = "merge" ]; then
	rm -rf $JEN_KARAF_FILE ${JEN_KARAF_DIR}
fi
if [ ! -d ${JEN_KARAF_DIR} ]; then
	if [ ! -f ${JEN_KARAF_FILE} ]; then
		wget $JEN_KARAF_SRC
	fi
	tar zxf $JEN_KARAF_FILE
fi

if [ "${JEN_BUILD_TYPE}" = "merge" -o ! -x "\${HOME}/bin/karaf" ]; then
	mkdir -p \${HOME}/bin
	cat >\${HOME}/bin/karaf <<@EOF@
#!/bin/bash

export JAVA_HOME=\$(readlink -f /usr/bin/java | sed "s:bin/java::")
cd \${HOME}/${JEN_KARAF_DIR}/bin/ || exit 1
. setenv
./karaf server
@EOF@
	chmod +x \${HOME}/bin/karaf
fi

if [ "${JEN_BUILD_TYPE}" = "merge" -o ! -s "/etc/init/karaf.conf" ]; then
	sudo -A /sbin/stop karaf
	cat >\${HOME}/karaf.conf <<@EOF@
description "ODL server ${JEN_KARAF_DIR}"

start on runlevel [2345]

setuid cisco
setgid cisco

respawn
console output

exec \${HOME}/bin/karaf
@EOF@
	sudo -A cp \${HOME}/karaf.conf /etc/init/karaf.conf
	sudo -A /sbin/start karaf
fi

export JAVA_HOME=\$(readlink -f /usr/bin/java | sed "s:bin/java::")
if ! grep JAVA_HOME \${HOME}/.bashrc; then
	echo export JAVA_HOME=\$JAVA_HOME >> \${HOME}/.bashrc
fi
cd ${JEN_KARAF_DIR}/bin
ls -al
. setenv
STATUS="\`./status\`"
while [ "\$STATUS" != 'Running ...' ]; do
	echo "Waiting for service to come up (status: \$STATUS)"
	sleep 10
	STATUS="\`./status\`"
done

echo "Waiting for service to respond (grab a coffee)"
time while ! curl --noproxy 127.0.0.1 --fail http://127.0.0.1:8181/apidoc/explorer/index.html ; do
        sleep 5
done
time while ! curl --noproxy 127.0.0.1 --fail 'http://127.0.0.1:8181/restconf/config/opendaylight-inventory:nodes/node/controller-config/yang-ext:mount/config:modules' ; do
        sleep 5
done
time while ! curl --noproxy 127.0.0.1 --fail 'http://admin:admin@127.0.0.1:8181/restconf/config/opendaylight-inventory:nodes' ; do
        sleep 5
done
_EOF_
chmod +x run-odl-install.sh
scp -F ssh_config run-odl-install.sh cosc-server:
ssh -F ssh_config -t cosc-server ./run-odl-install.sh
