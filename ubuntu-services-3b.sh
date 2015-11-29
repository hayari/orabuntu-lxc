#!/bin/bash

echo "============================================"
echo "Script:  ubuntu-services-3b.sh              "
echo "============================================"

echo "============================================"
echo "This script extracts customzed files to     "
echo "the container required for running Oracle   "
echo "============================================"

echo "============================================"
echo "This script is re-runnable                  "
echo "============================================"

# GLS 20151127 New test for bind9 status.  Terminates script if bind9 status is not valid.

function GetBindStatus {
sudo service bind9 status | grep Active | cut -f1-6 -d' ' | sed 's/ *//g'
}
BindStatus=$(GetBindStatus)

clear

echo ''
echo "============================================"
echo "Checking status of bind9 DNS...             "
echo "============================================"

if [ $BindStatus != 'Active:active(running)' ]
then
	echo ''
	echo "Bind9 is NOT RUNNING with correct status of:  Active: active (running)"
	echo ''
	echo "============================================"
	echo "Bind9 DNS status ...                        "
	echo "============================================"
	echo ''
	sudo service bind9 status
	echo ''
	echo "============================================"
	echo "Bind9 DNS status incorrect.                  "
	echo "============================================"
	sleep 5
	echo ''
	echo "============================================"
	echo "!! FIX PROBLEM with bind9 and retry script. "
	echo "============================================"
	echo ''
	exit
else
	echo ''
	echo "Bind9 is RUNNING with correct status of:  Active: active (running)"
	echo ''
	echo "============================================"
	echo "Bind9 DNS status ...                        "
	echo "============================================"
	echo ''
	sudo service bind9 status
	echo ''
	echo "============================================"
	echo "Bind9 DNS status complete.                  "
	echo "============================================"
	sleep 5
	echo ''
	echo "============================================"
	echo "Continuing with script execution.           "
	echo "============================================"
fi

echo ''
echo "============================================"
echo "Status check of bind9 DNS completed.        "
echo "============================================"
echo ''

# GLS 20151127 New test for bind9 status.  Terminates script if bind9 status is not valid.

# GLS 20151127 New DHCP server checks.  Terminates script if DHCP status is invalid.

clear

function GetDHCPStatus {
sudo service isc-dhcp-server status | grep Active | cut -f1-6 -d' ' | sed 's/ *//g'
}
DHCPStatus=$(GetDHCPStatus)

echo ''
echo "============================================"
echo "Checking status of DHCP...                  "
echo "============================================"

if [ $DHCPStatus != 'Active:active(running)' ]
then
	echo ''
	echo "DHCP is NOT RUNNING with correct status of:  Active: active (running)"
	echo ''
	echo "============================================"
	echo "DHCP status ...                             "
	echo "============================================"
	echo ''
	sudo service isc-dhcp-server status
	echo ''
	echo "============================================"
	echo "DHCP status incorrect.                      "
	echo "============================================"
	sleep 5
	echo ''
	echo "============================================"
	echo "!! FIX PROBLEM with DHCP and retry script.  "
	echo "============================================"
	echo ''
	exit
else
	echo ''
	echo "DHCP is RUNNING with correct status of:  Active: active (running)"
	echo ''
	echo "============================================"
	echo "DHCP status ...                             "
	echo "============================================"
	echo ''
	sudo service isc-dhcp-server status
	echo ''
	echo "============================================"
	echo "DHCP status complete.                       "
	echo "============================================"
	sleep 5
	echo ''
	echo "============================================"
	echo "Continuing with script execution.           "
	echo "============================================"
fi

echo ''
echo "============================================"
echo "Status check of DHCP completed.        "
echo "============================================"
echo ''

# GLS 20151128 New DHCP status check end.

# GLS 20151128 Google ping test start.

clear

echo ''
echo "============================================"
echo "Begin google.com ping test...               "
echo "Be patient...                               "
echo "============================================"
echo ''

ping -c 3 google.com

echo ''
echo "============================================"
echo "End google.com ping test                    "
echo "============================================"
echo ''

sleep 3

clear

function CheckNetworkUp {
ping -c 1 google.com | grep 'packet loss' | cut -f1 -d'%' | cut -f6 -d' ' | sed 's/^[ \t]*//;s/[ \t]*$//'
}
NetworkUp=$(CheckNetworkUp)

echo $NetworkUp

if [ "$NetworkUp" -ne 0 ]
then
echo ''
echo "============================================"
echo "Destination google.com is not pingable      "
echo "Address network issues and retry script     "
echo "Script exiting                              "
echo "============================================"
echo ''
exit
fi

clear

echo ''
echo "============================================"
echo "DNS nslookup test...                        "
echo "Be patient...sometimes!                     "
echo "============================================"
echo ''

function GetLookup {
nslookup vmem1 | grep 10.207.39.1 | sed 's/\.//g' | sed 's/: //g'
}
Lookup=$(GetLookup)

if [ $Lookup != 'Address10207391' ]
then
	echo ''
	echo "DNS Lookups NOT working."
	echo ''
	echo "============================================"
	echo "DNS lookups status ...                             "
	echo "============================================"
	nslookup vmem1
	echo ''
	echo "============================================"
	echo "!! FIX PROBLEM with DNS and retry script.  "
	echo "============================================"
	exit
else
	echo ''
	echo "DNS Lookups are working properly."
	echo ''
	echo "============================================"
	echo "DNS Lookup ...                             "
	echo "============================================"
	nslookup vmem1
	echo ''
	echo "============================================"
	echo "Continuing with script execution.           "
	echo "============================================"
fi

echo ''
echo "============================================"
echo "Status check of DNS Lookups completed.      "
echo "============================================"
echo ''

sleep 5

clear

sudo lxc-start -n lxcora0 > /dev/null 2>&1

sleep 5

function CheckContainerUp {
sudo lxc-ls -f | grep lxcora0 | sed 's/  */ /g' | grep RUNNING  | cut -f2 -d' '
}
ContainerUp=$(CheckContainerUp)

if [ $ContainerUp != 'RUNNING' ]
then
sudo lxc-stop  -n lxcora0
sudo lxc-start -n lxcora0
fi

function CheckPublicIP {
sudo lxc-ls -f | sed 's/  */ /g' | grep RUNNING | cut -f3 -d' ' | sed 's/,//' | cut -f1-3 -d'.' | sed 's/\.//g'
}
PublicIP=$(CheckPublicIP)

clear

echo "============================================"
echo "Bringing up public ip on lxcora0...        "
echo "============================================"
echo ''

sleep 5

while [ "$PublicIP" -ne 1020739 ]
do
PublicIP=$(CheckPublicIP)
echo "Waiting for lxcora0 Public IP to come up..."
sudo lxc-ls -f | sed 's/  */ /g' | grep RUNNING | cut -f3 -d' ' | sed 's/,//'
sleep 1
done

echo ''
echo "===========================================" 
echo "Public IP is up on lxcora0                "
echo ''
sudo lxc-ls -f
echo ''
echo "==========================================="
echo "Container Up.                              "
echo "==========================================="

echo "Sleeping for 10 seconds..."
sleep 10
clear

echo ''
echo "==========================================="
echo "Verify no-password ssh working to lxcora0 "
echo "==========================================="
echo ''

sleep 2

ssh root@lxcora0 uname -a

echo ''
echo "==========================================="
echo "Verification of no-password ssh completed. "
echo "==========================================="

sleep 4

clear

echo ''
echo "================================================"
echo "Logged into LXC container lxcora0              "
echo "Installing files and packages for Oracle...     "
echo "================================================"
echo ''

ssh root@lxcora0 /root/packages.sh
ssh root@lxcora0 /root/create_users.sh
ssh root@lxcora0 /root/lxc-services.sh
ssh root@lxcora0 /root/install_grid.sh

sudo tar -vP --extract --file=lxc-lxcora01.tar /var/lib/lxc/lxcora01/rootfs/home/grid/grid/rpm/cvuqdisk-1.0.9-1.rpm
sudo mkdir -p /var/lib/lxc/lxcora0/rootfs/home/grid/grid/rpm
sudo mv /var/lib/lxc/lxcora01/rootfs/home/grid/grid/rpm/cvuqdisk-1.0.9-1.rpm /var/lib/lxc/lxcora0/rootfs/home/grid/grid/rpm/cvuqdisk-1.0.9-1.rpm
sudo cp -p /var/lib/lxc/lxcora0/rootfs/home/grid/grid/rpm/cvuqdisk-1.0.9-1.rpm /var/lib/lxc/lxcora0/rootfs/root/.

ssh root@lxcora0 rpm -Uvh /home/grid/grid/rpm/cvuqdisk-1.0.9-1.rpm

# sudo tar -P --extract --file=lxc-lxcora01.tar /var/lib/lxc/lxcora0/rootfs/home/grid/.bashrc
# sudo tar -vP --extract --file=lxc-lxcora01.tar /var/lib/lxc/lxcora01/rootfs/home/oracle/.bashrc
sudo cp ~/Downloads/oracle.bash_profile /var/lib/lxc/lxcora0/rootfs/home/oracle/.bash_profile
sudo cp ~/Downloads/oracle.bashrc /var/lib/lxc/lxcora0/rootfs/home/oracle/.bashrc
sudo cp ~/Downloads/oracle.kshrc /var/lib/lxc/lxcora0/rootfs/home/oracle/.kshrc

sudo cp -p ~/Downloads/rc.local /var/lib/lxc/lxcora0/rootfs/etc/rc.local
ssh root@lxcora0 chown grid:oinstall /home/grid/grid
ssh root@lxcora0 chown grid:oinstall /home/grid/grid/rpm
scp edit_bashrc root@lxcora0:/home/grid/.
ssh root@lxcora0 chown grid:oinstall /home/grid/edit_bashrc
ssh root@lxcora0 chmod 755 /home/grid/edit_bashrc
ssh root@lxcora0 usermod --password `perl -e "print crypt('grid','grid');"` grid
ssh root@lxcora0 usermod --password `perl -e "print crypt('oracle','oracle');"` oracle
ssh root@lxcora0 usermod -g oinstall oracle
ssh root@lxcora0 chown oracle:oinstall /home/oracle/.bash_profile
ssh root@lxcora0 chown oracle:oinstall /home/oracle/.bashrc
ssh root@lxcora0 chown oracle:oinstall /home/oracle/.kshrc
ssh root@lxcora0 chown oracle:oinstall /home/oracle/.bash_logout
ssh root@lxcora0 chown oracle:oinstall /home/oracle/.
ssh root@lxcora0 sed -i '/ORACLE_SID/d' /home/oracle/.bashrc

echo "================================================"
echo "Password for grid:  grid (same as username)     "
echo "================================================"
echo ''

ssh grid@lxcora0 /home/grid/edit_bashrc

sleep 5

clear

echo ''
echo "================================================"
echo "Verify .bashrc file has umask 022 entry         "
echo "================================================"
echo ''
echo "================================================"
echo "Password for grid:  grid (same as username)     "
echo "================================================"
echo ''

ssh grid@lxcora0 cat .bashrc

echo ''
echo "================================================"
echo "Verified .bashrc file has umask 022 entry       "
echo "================================================"
echo ''
sleep 5

clear

echo "==========================================="
echo "Stopping lxcora0 container...             "
echo "==========================================="
echo ''
sudo lxc-stop -n lxcora0

while [ "$ContainerUp" = 'RUNNING' ]
do
sleep 1
sudo lxc-ls -f
ContainerUp=$(CheckContainerUp)
echo ''
echo $ContainerUp
done
echo ''
echo "==========================================="
echo "Container stopped.                         "
echo "==========================================="

sleep 3

clear

echo '' 
echo "================================================"
echo "Now run ubuntu-services-3c.sh X                 "
echo "Note that ubuntu-services-3c.sh takes an input  "
echo "variable X which is the number of LXC RAC nodes "
echo "you wish to create.  If X is not entered, the   "
echo "build defaults to a 2-node RAC cluster.  If X is"
echo "set to 6 it will create a 6-node RAC            "
echo "================================================"
