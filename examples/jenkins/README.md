A set of scripts used from a Jenkins slave to:

* Start or reuse a VIRL topology
* Wait for it to become active and configured
* Modify it to suit our needs
* Run our Jenkins tests against it
* Shut it doen again (or leave it around for the next run)

do-build.sh
===========

do-build is the top script and gets run from Jenkins. It sets a bunch of 
environment vars used by the other scripts and then downloads and executes
the other scripts.

prepare-virl.sh
===============

Interfaces with the UWM server to setup ssh key access for the guest user.
Then we upload some images into VIRL and setup a new Linux flavor with
custom memory, cpu and disk settings.

start-virl.sh
=============

A tricky bit. One of the things to remember is that just because the simulation is active doesn't mean that all of its console ports are assigned or that the
nodes inside the simulation have booted and finished their initial
configurations.

1. Starting the VIRL simulation is easy enough, but we need to wait for it to
   become active. 
1. Once it is active we need to wait for the nodes (Linux boxes, IOS routers,
   etc) to become active by checking the number of live nodes and comparing it
   to the number of defined nodes.
1. Export the updated VIRL file containing the AutoNetKit information on the
   live nodes.
1. Wait for IOS nodes to parse their configs (MGBL-CVAC-4-CONFIG_DONE).
1. Create an SSH config file to easily connect into the nodes via the lxc
   bridge host.
1. Enable ssh on the routers by creating SSH hostkeys.
1. For merge builds only:
   * Install and setup upstream software dependencies. We'll reuse this in verify builds later on for increased performance
   * Setup proxies
   * Enable passwordless sudo
   * Reboot servers in parallel
   * Wait in parallel for cloudinit to finish on rebooted servers

Note that the program used to parallellize the commands is mfork which can
be found online.

odl-setup.sh
============

The example here is from Jenkins code created to test a client of an ODL
server. This script installs the ODL server inside one of the VIRL nodes
so that our client can be tested against it.

As explained earlier we have merge and verify builds. 

* In verify builds we'll assume that the software is already installed, we
  just need to wait for it to become active.
* In merge builds we need to do that too, but we need to install the software
  first and set it up as a service so that it gets started automatically.

cosc-setup.sh
=============

The code that actually tests the ODL client against the server we setup and
the VIRL network topology.

Your code will obviously vary greatly from this script, but the script shows
nicely how to setup back-to-back SSH port forwards to run the tests.

