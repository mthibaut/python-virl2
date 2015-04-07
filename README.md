virl-utils
==========

Utilities for integrating VIRL with the developer experience.

These scripts aim to simplify interactions with the Cisco VIRL API. They act
as frontends to the API in various ways and make parsing its JSON or XML 
outputs easier.

Scripts
=======

Parsing
-------

* virl-dictval: parses a JSON dictionary and retrieves a value for a given key.
* virl-flavors: guests can come in various sizes (cpu, disk, memory, etc), this tool queries the VIRL server's database for its defined flavors.
* virl-images: same as virl-flavors but for images.
* virl-nodes: list the nodes in a VIRL file.
* virl-node-val: print a value from the VIRL file given a node and a key.
* virl-ports: print the ports that can be used to connect to a node.
* virl-subdictval: retrieve a value two levels down in a JSON file.

Complex API interactions
------------------------

* virl-ensure-image: ensure that an image exists on a VIRL server.

Node interactions
-----------------

* virl-fixroot.sh: modify a remote linux machine to allow direct root access via SSH
* virl-ios-chat: chat with an IOS machine, similar to a pppd script chatting with a modem to connect a serial line.
* virl-ios-login: similar to virl-ios-chat, but specialized in logging in - this is typically done to ensure that a machine is online after receiving the expected configuration console messages.
* virl-ios-login-chat: combines virl-ios-login and virl-ios-chat in one command to login and then chat with an IOS machine.
* virl-ios-wait: wait for a console message on an IOS machine - typically used to wait until an IOS node is fully online.
* virl-mk-ssh-config: create an SSH config file to interact with VIRL nodes via the lxc bridge.

API
---

* virl_utils.py: reusable code used by the above tools.

Examples
========

You can find examples here:

* [Jenkins](examples/README.md)
