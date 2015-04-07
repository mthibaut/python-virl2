#!/bin/sh
#
# This script fixes the remote host to allow root to login directly.
#
# Use this script by
#  1. Copying it to a remote host
#  2. Setting the PASSWORD environment variable
#  3. Executing the script
# 
# For example:
#    scp virl-fixroot.sh guest@server:
#    ssh guest@server sh -c "PASSWORD=guest ./virl-fixroot.sh"

mkdir -p ${HOME}/bin
cat > ${HOME}/bin/askpass <<_EOF_
#!/bin/bash
echo $PASSWORD
_EOF_
chmod +x ${HOME}/bin/askpass
export SUDO_ASKPASS=${HOME}/bin/askpass

cat > ${HOME}/bin/fixroot <<_EOF_
#!/bin/bash
set -x
sed -i 's/^#?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
mkdir -p /root/.ssh
chmod 0700 /root/.ssh
if [ -s "${HOME}/.ssh/authorized_keys" ]; then
	cp ${HOME}/.ssh/authorized_keys /root/.ssh/authorized_keys
	chmod 0600 /root/.ssh/authorized_keys; chown -Rh root:root /root/.ssh
fi
service ssh restart
service sshd restart
_EOF_
chmod +x ${HOME}/bin/fixroot
sudo -A ${HOME}/bin/fixroot
