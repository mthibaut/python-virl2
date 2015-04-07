#!/bin/sh -vx

# All commands here are against the UWM server, not against the STD server.
export VIRL_STD_NAME=${JEN_VIRL_UWM_NAME:="uwmadmin"}
export VIRL_STD_PASSWORD=${JEN_VIRL_UWM_PASSWORD:="password"}

THEHOST=$1
if [ -n "${THEHOST}" ]; then
	DOMAIN=`echo $THEHOST | sed -e 's/^[^.]*//'`
	if [ -z "${DOMAIN}" ]; then
		THEHOST="${THEHOST}.cisco.com"
	fi
	export VIRL_STD_URL="http://${THEHOST}:19399"
	export VIRL_UWM_URL="http://${THEHOST}:19400"
fi

# SSH Key
if [ -s "$JEN_SSH_PUBKEYFILE" ]; then
	JEN_SSH_PUB=`cat ${JEN_SSH_PUBKEYFILE}`
	virl_uwm_client user-edit --name guest --publickey "$JEN_SSH_PUB"
fi

# XRv image
COUNT=`virl_uwm_client image-info | virl-images -s 'IOS XRv' -r '5.1.1.53U' | wc -l`
if [ $COUNT -eq 0 ]; then
	virl_uwm_client image-create --release "5.1.1.53U" --subtype 'IOS XRv' --image-url "${JEN_IOSXRV_SRC}"
fi

# Server image for verify builds
COUNT=`virl_uwm_client image-info | virl-images -s 'server' -v "integration-java+python" | wc -l`
if [ $COUNT -eq 0 ]; then
	virl_uwm_client image-create --release "integration-java+python" --version "integration-java+python" --subtype "server" --image-url ${JEN_VRFY_SRC}
fi

# Install flavor
#COUNT=`virl_uwm_client flavor-info | virl-flavors -n m1.petite | wc -l`
#if [ $COUNT -eq 0 ]; then
	#virl_uwm_client flavor-create -n m1.petite -r 2048 -c 2 -d 4
#fi
# Install flavor
COUNT=`virl_uwm_client flavor-info | virl-flavors -n m1.hobbit | wc -l`
if [ $COUNT -eq 0 ]; then
	virl_uwm_client flavor-create -n m1.hobbit -r 10240 -c 4 -d 4
fi
