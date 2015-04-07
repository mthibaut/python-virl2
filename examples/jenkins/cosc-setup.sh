#!/bin/bash -vx

# This script may not be as useful to you. It sets up the configuration of
# the code to be tested by Jenkins. Yours will vary wildly. However, it does
# nicely show how to do the back-and-forth SSH connection setup.

XRV1_ADDRESS=`virl-node-val -n iosxrv-1 AutoNetkit.mgmt_ip < ${JEN_VIRL_FILE_OUT}`
XRV2_ADDRESS=`virl-node-val -n iosxrv-2 AutoNetkit.mgmt_ip < ${JEN_VIRL_FILE_OUT}`
PORT=`echo $[ 10000 + $[ RANDOM % 1000 ]]`

cat > ${JEN_SRC_DIR}/src/settings/jenkins.py <<_EOF_
config = {
	'network_device':{
		'iosxrv-1':{
			'address': '${XRV1_ADDRESS}',
			'port': 830,
			'password': 'cisco',
			'username': 'cisco'},
		'iosxrv-2':{
			'address': '${XRV2_ADDRESS}',
			'port': 830,
			'password': 'cisco',
			'username': 'cisco'}},
		'odl_server':{
			'address': '127.0.0.1',
			'port': ${PORT},
			'password': 'admin',
			'username': 'admin'}}
_EOF_
# This is just for me: I forward port 8181 on my laptop to the jenkins build server
# to run tests from my eclipse.
cat > ${JEN_SRC_DIR}/src/settings/mthibaut.py <<_EOF_
config = {
	'network_device':{
		'iosxrv-1':{
			'address': '${XRV1_ADDRESS}',
			'port': 830,
			'password': 'cisco',
			'username': 'cisco'},
		'iosxrv-2':{
			'address': '${XRV2_ADDRESS}',
			'port': 830,
			'password': 'cisco',
			'username': 'cisco'}},
		'odl_server':{
			'address': '127.0.0.1',
			'port': 8181,
			'password': 'admin',
			'username': 'admin'}}
_EOF_

cat >runasme.sh <<_EOF_
#!/bin/bash
export NETWORK_PROFILE=jenkins

cd $JEN_BUILD_DIR || exit 1
. ./environment1.sh
${JEN_SRC_DIR}/src/learning_lab/01_connected.py

export PYTHONPATH="${JEN_SRC_DIR}/src"
let "TESTS = 0"
let "FAILURES = 0"

for f in ${JEN_SRC_DIR}/test/test_*.py ; do
	let "TESTS += 1"
	echo "Now running test \$f"
	python \$f
	if [ \$? -gt 0 ]; then
		let "FAILURES += 1"
	fi
done

echo "Tests run: \$TESTS - failed tests: \$FAILURES"
echo \$TESTS > tests
echo \$FAILURES > failures
exit \$FAILURES
_EOF_
chmod +x runasme.sh

# SSH to the remote and SSH right back. Then run the tests with our port forwards alive.
# Wish this could be done in an easier way...
ssh -A -F ssh_config -R ${PORT}:localhost:22 -L ${PORT}:localhost:8181 cosc-server "ssh -o stricthostkeychecking=no -p ${PORT} $(whoami)@localhost ${PWD}/runasme.sh"

FAILURES=`cat failures`
if [ -z "$FAILURES" ]; then
	exit 255
fi
exit $FAILURES
