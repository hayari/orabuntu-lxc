#!/bin/bash

#    Copyright 2015-2019 Gilbert Standen
#    This file is part of Orabuntu-LXC.

#    Orabuntu-LXC is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    Orabuntu-LXC is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Orabuntu-LXC.  If not, see <http://www.gnu.org/licenses/>.

#    v2.4 		GLS 20151224
#    v2.8 		GLS 20151231
#    v3.0 		GLS 20160710 Updates for Ubuntu 16.04
#    v4.0 		GLS 20161025 DNS DHCP services moved into an LXC container
#    v5.0 		GLS 20170909 Orabuntu-LXC Multi-Host
#    v6.0-AMIDE-beta	GLS 20180106 Orabuntu-LXC AmazonS3 Multi-Host Docker Enterprise Edition (AMIDE)

#    Note that this software builds a containerized DNS DHCP solution (bind9 / isc-dhcp-server).
#    The nameserver should NOT be the name of an EXISTING nameserver but an arbitrary name because this software is CREATING a new LXC-containerized nameserver.
#    The domain names can be arbitrary fictional names or they can be a domain that you actually own and operate.
#    There are two domains and two networks because the "seed" LXC containers are on a separate network from the production LXC containers.
#    If the domain is an actual domain, you will need to change the subnet using the subnets feature of Orabuntu-LXC
#
#!/bin/bash

clear

MajorRelease=$1
OracleRelease=$1$2
OracleVersion=$1.$2
NumCon=$3
NameServer=$4
MultiHost=$5
DistDir=$6
Product=$7

function SoftwareVersion { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

function GetLXCVersion {
        lxc-create --version
}
LXCVersion=$(GetLXCVersion)

function GetMultiHostVar1 {
        echo $MultiHost | cut -f1 -d':'
}
MultiHostVar1=$(GetMultiHostVar1)

function GetMultiHostVar2 {
        echo $MultiHost | cut -f2 -d':'
}
MultiHostVar2=$(GetMultiHostVar2)

function GetMultiHostVar7 {
        echo $MultiHost | cut -f7 -d':'
}
MultiHostVar7=$(GetMultiHostVar7)

GetLinuxFlavors(){
if   [[ -e /etc/oracle-release ]]
then
        LinuxFlavors=$(cat /etc/oracle-release | cut -f1 -d' ')
elif [[ -e /etc/redhat-release ]]
then
        LinuxFlavors=$(cat /etc/redhat-release | cut -f1 -d' ')
elif [[ -e /usr/bin/lsb_release ]]
then
        LinuxFlavors=$(lsb_release -d | awk -F ':' '{print $2}' | cut -f1 -d' ')
elif [[ -e /etc/issue ]]
then
        LinuxFlavors=$(cat /etc/issue | cut -f1 -d' ')
else
        LinuxFlavors=$(cat /proc/version | cut -f1 -d' ')
fi
}
GetLinuxFlavors

function TrimLinuxFlavors {
echo $LinuxFlavors | sed 's/^[ \t]//;s/[ \t]$//'
}
LinuxFlavor=$(TrimLinuxFlavors)

if   [ $LinuxFlavor = 'Oracle' ]
then
        function GetOracleDistroRelease {
                sudo cat /etc/oracle-release | cut -f5 -d' ' | cut -f1 -d'.'
        }
        OracleDistroRelease=$(GetOracleDistroRelease)
        if   [ $OracleDistroRelease -eq 7 ] || [ $OracleDistroRelease -eq 6 ]
        then
                CutIndex=7
        elif [ $OracleDistroRelease -eq 8 ]
        then
                CutIndex=6
        fi
        function GetRedHatVersion {
                sudo cat /etc/redhat-release | cut -f"$CutIndex" -d' ' | cut -f1 -d'.'
        }
        RedHatVersion=$(GetRedHatVersion)
	RHV=$RedHatVersion
        function GetOracleDistroRelease {
                sudo cat /etc/oracle-release | cut -f5 -d' ' | cut -f1 -d'.'
        }
        OracleDistroRelease=$(GetOracleDistroRelease)
        Release=$OracleDistroRelease
        LF=$LinuxFlavor
        RL=$Release
elif [ $LinuxFlavor = 'Red' ] || [ $LinuxFlavor = 'CentOS' ]
then
	if   [ $LinuxFlavor = 'Red' ]
        then
                function GetRedHatVersion {
                        sudo cat /etc/redhat-release | rev | cut -f2 -d' ' | cut -f2 -d'.'
                }
        elif [ $LinuxFlavor = 'CentOS' ]
        then
                function GetRedHatVersion {
                        cat /etc/redhat-release | sed 's/ Linux//' | cut -f1 -d'.' | rev | cut -f1 -d' '
                }
        fi
	RedHatVersion=$(GetRedHatVersion)
	RHV=$RedHatVersion
        Release=$RedHatVersion
        LF=$LinuxFlavor
        RL=$Release
elif [ $LinuxFlavor = 'Fedora' ]
then
        CutIndex=3
        function GetRedHatVersion {
                sudo cat /etc/redhat-release | cut -f"$CutIndex" -d' ' | cut -f1 -d'.'
        }
        RedHatVersion=$(GetRedHatVersion)
	RHV=$RedHatVersion
        if   [ $RedHatVersion -ge 28 ]
        then
                Release=8
        elif [ $RedHatVersion -ge 19 ] && [ $RedHatVersion -le 27 ]
        then
                Release=7
        elif [ $RedHatVersion -ge 12 ] && [ $RedHatVersion -le 18 ]
        then
                Release=6
        fi
        LF=$LinuxFlavor
        RL=$Release
elif [ $LinuxFlavor = 'Ubuntu' ]
then
        function GetUbuntuVersion {
                cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'='
        }
        UbuntuVersion=$(GetUbuntuVersion)
        LF=$LinuxFlavor
        RL=$UbuntuVersion
        function GetUbuntuMajorVersion {
                cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'=' | cut -f1 -d'.'
        }
        UbuntuMajorVersion=$(GetUbuntuMajorVersion)
fi

clear

echo ''
echo "=============================================="
echo "Next script to run: uekulele-services-4.sh    "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Script:  uekulele-services-4.sh NumCon        "
echo "=============================================="
echo ''
echo "=============================================="
echo "This script is re-runnable.                   "
echo "This script clones additional containers.     "
echo "=============================================="
echo ''
echo "=============================================="
echo "NumCon is the number of RAC nodes             "
echo "NumCon (small integer)                        "
echo "NumCon defaults to value '2'                  "
echo "=============================================="

if [ -z $3 ]
then
	NumCon=2
else
	NumCon=$3
fi

ContainerPrefix=ora$1$2c
CP=$ContainerPrefix

function GetSeedContainerName {
	sudo lxc-ls -f | grep oel$OracleRelease | cut -f1 -d' '
}
SeedContainerName=$(GetSeedContainerName)

echo ''
echo "=============================================="
echo "Number of LXC Container RAC Nodes = $NumCon   "
echo "=============================================="
echo ''
echo "=============================================="
echo "If wrong number of desired RAC nodes, then    "
echo "<ctrl>+c and restart script to set            "
echo "Sleeping 15 seconds...                        "
echo "=============================================="
echo ''
echo "=============================================="
echo "This script creates oracle-ready lxc clones   "
echo "for oracle-ready RAC container nodes          "
echo "=============================================="

sleep 5

clear

function GetMultiHostVar4 {
        echo $MultiHost | cut -f4 -d':'
}
MultiHostVar4=$(GetMultiHostVar4)

echo ''
echo "=============================================="
echo "Establish sudo privileges...                  "
echo "=============================================="
echo ''

echo $MultiHostVar4 | sudo -S date

echo ''
echo "=============================================="
echo "Privileges established.                       "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Stopping $SeedContainerName seed container...  "
echo "(OEL 5 shutdown can take awhile...patience)   "
echo "(OEL 6 and OEL 7 are relatively fast shutdown)"
echo "=============================================="
echo ''

function CheckContainerUp {
sudo lxc-ls -f | grep $SeedContainerName | sed 's/  */ /g' | egrep 'RUNNING|STOPPED'  | cut -f2 -d' '
}
ContainerUp=$(CheckContainerUp)
if [ $LinuxFlavor = 'CentOS' ] && [ $Release -eq 6 ]
then
        sudo lxc-stop -n $SeedContainerName -k > /dev/null 2>&1
else
        sudo lxc-stop -n $SeedContainerName    > /dev/null 2>&1
fi


while [ "$ContainerUp" = 'RUNNING' ]
do
	sleep 1
	ContainerUp=$(CheckContainerUp)
done

sudo lxc-ls -f

echo ''
echo "=============================================="
echo "Seed container stopped.                       "
echo "=============================================="

sleep 5

clear

if [ $MultiHostVar2 = 'Y' ]
then
	sudo sed -i "s/MtuSetting/$MultiHostVar7/g" /var/lib/lxc/$SeedContainerName/config
fi

echo ''
echo "=============================================="
echo "Networking add-ons for $Product...            "
echo "=============================================="
echo ''

sleep 5

clear

sudo /opt/olxc/"$DistDir"/products/$Product/$Product.net $MultiHostVar1
	
echo ''
echo "=============================================="
echo "Done: Networking add-ons for $Product.        "
echo "=============================================="
echo ''

sleep 5

clear

if [ -f /var/lib/lxc/$SeedContainerName/rootfs/root/lxc-services.sh ]
then
        sudo sed -i 's/yum install/yum -y install/g' /var/lib/lxc/$SeedContainerName/rootfs/root/lxc-services.sh >/dev/null 2>&1
fi

sleep 5

clear

echo ''
echo "=============================================="
echo "Clone $SeedContainerName to $NumCon containers"
echo "=============================================="
echo ''

let CloneIndex=10
let CopyCompleted=0

while [ $CopyCompleted -lt $NumCon ]
do
	# GLS 20160707 updated to use lxc-copy instead of lxc-clone for Ubuntu 16.04
	# GLS 20160707 continues to use lxc-clone for Ubuntu 15.04 and 15.10

	RedHatVersion=$(GetRedHatVersion)

	function CheckDNSLookup {
		nslookup $ContainerPrefix$CloneIndex $NameServer | grep -v '#' | grep Address | grep '10\.207\.39' | wc -l
	}
	DNSLookup=$(CheckDNSLookup)

	if [ $Release -ge 7 ] || [ $Release -eq 6 ]
	then
		while [ $DNSLookup -eq 1 ]
		do
			CloneIndex=$((CloneIndex+1))
			DNSLookup=$(CheckDNSLookup)
		done
		if [ $DNSLookup -eq 0 ]
		then
			echo ''
			echo "=============================================="
			echo "Clone $SeedContainerName to $CP$CloneIndex    "
			echo "=============================================="
			echo ''

			echo "Clone Container Name = $ContainerPrefix$CloneIndex"

      			sudo lxc-copy -n $SeedContainerName -N $ContainerPrefix$CloneIndex

			if [ $MajorRelease -ge 7 ]
			then
                        	sudo sed -i "s/$SeedContainerName/$ContainerPrefix$CloneIndex/g"        /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/hostname
                        fi
			sudo sed -i "s/$SeedContainerName/$ContainerPrefix$CloneIndex/g"        /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/sysconfig/network-scripts/ifcfg-eth0
			sudo sed -i "s/HostName/$ContainerPrefix$CloneIndex/g"        		/var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/sysconfig/network-scripts/ifcfg-eth0
                        sudo sed -i "s/$SeedContainerName/$ContainerPrefix$CloneIndex/g"        /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/sysconfig/network
                        sudo sed -i "s/$SeedContainerName/$ContainerPrefix$CloneIndex/g"        /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/hosts
		fi
	fi

	sudo sed -i "s/$SeedContainerName/$ContainerPrefix$CloneIndex/g" /var/lib/lxc/$ContainerPrefix$CloneIndex/config
	sudo sed -i "s/\.10/\.$CloneIndex/g" /var/lib/lxc/$ContainerPrefix$CloneIndex/config
	sudo sed -i 's/sx1/sw1/g' /var/lib/lxc/$ContainerPrefix$CloneIndex/config
	sudo sed -i "s/mtu = 1500/mtu = $MultiHostVar7/g" /var/lib/lxc/$ContainerPrefix$CloneIndex/config
#       sudo sed -i "s/lxc\.mount\.entry = \/dev\/lxc_luns/#lxc\.mount\.entry = \/dev\/lxc_luns/g" /var/lib/lxc/$ContainerPrefix$CloneIndex/config
#       sudo sed -i "/domain-name-servers/s/10.207.29.2/10.207.39.2/g" /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/dhcp/dhclient.conf

	echo ''
	echo "=============================================="
	echo "OpenvSwitch Networking for $Product ...       "
	echo "=============================================="
	echo ''

	sudo /opt/olxc"$DistDir"/products/$Product/$Product.cnf $ContainerPrefix $CloneIndex $Product $MultiHostVar1
	
	echo ''
	echo "=============================================="
	echo "Done: OpenvSwitch Networking for $Product.    "
	echo "=============================================="
	echo ''

	sleep 5

	function GetHostName (){ echo $ContainerPrefix$CloneIndex\1; }
	HostName=$(GetHostName)

	sudo sed -i "s/$HostName/$ContainerPrefix$CloneIndex/" /var/lib/lxc/$ContainerPrefix$CloneIndex/rootfs/etc/sysconfig/network

	if [ $Release -ge 7 ]
	then
		echo ''
		echo "=============================================="
		echo "Create $CP$CloneIndex Onboot Service...       "
		echo "=============================================="

		sudo sh -c "echo '#!/bin/bash'										>  /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '#'											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '# Manage the Oracle RAC LXC containers'						>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '#'											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo 'start() {'										>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '  exec lxc-start -n $ContainerPrefix$CloneIndex > /dev/null 2>&1'			>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '}'											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo ''											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo 'stop() {'										>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '  exec lxc-stop -n $ContainerPrefix$CloneIndex > /dev/null 2>&1'			>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '}'											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo ''											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo 'case \$1 in'										>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo '  start|stop) \"\$1\" ;;'								>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"
		sudo sh -c "echo 'esac'											>> /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh"

		sudo chmod +x /etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh
	
		sudo sh -c "echo '[Unit]'                                                        			>  /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'Description=$ContainerPrefix$CloneIndex Service'                               	>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'Wants=network-online.target sw1.service $NameServer.service'          		>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'After=network-online.target sw1.service $NameServer.service'          		>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo ''                                                             			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo '[Service]'                                                    			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'Type=oneshot'                                                 			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'User=root'                                                    			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'RemainAfterExit=yes'                                          			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'ExecStart=/etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh start' 	>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'ExecStop=/etc/network/openvswitch/strt_$ContainerPrefix$CloneIndex.sh stop'   	>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo ''                                                             			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo '[Install]'                                                    			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
		sudo sh -c "echo 'WantedBy=multi-user.target'                                   			>> /etc/systemd/system/$ContainerPrefix$CloneIndex.service"
	
		sudo chmod 644 /etc/systemd/system/$ContainerPrefix$CloneIndex.service
	
		echo ''
		sudo cat /etc/systemd/system/$ContainerPrefix$CloneIndex.service
		echo ''
		sudo systemctl enable $ContainerPrefix$CloneIndex
	
		echo ''
		echo "=============================================="
		echo "Created $CP$CloneIndex Onboot Service.        "
		echo "=============================================="
		echo ''

        	if [ $(SoftwareVersion $LXCVersion) -ge $(SoftwareVersion "2.1.0") ]
        	then
                	sudo lxc-update-config -c /var/lib/lxc/$CP$CloneIndex/config
        	fi

		CopyCompleted=$((CopyCompleted+1))
		CloneIndex=$((CloneIndex+1))

		sleep 5

		clear

	elif [ $Release -eq 6 ]
	then
		echo ''
		echo "=============================================="
		echo "Create $CP$CloneIndex Onboot Service...       "
		echo "=============================================="
		echo ''

		sudo cp -p /etc/network/openvswitch/container-service-linux6.sh /etc/init.d/lxc_$ContainerPrefix$CloneIndex
		sudo sed -i "s/LXCON/$ContainerPrefix$CloneIndex/g" /etc/init.d/lxc_$ContainerPrefix$CloneIndex
		sudo chmod 755 /etc/init.d/lxc_$ContainerPrefix$CloneIndex
		sudo chown $Owner:$Group /etc/init.d/lxc_$ContainerPrefix$CloneIndex
		sudo chkconfig --add lxc_$ContainerPrefix$CloneIndex
		sudo chkconfig lxc_$ContainerPrefix$CloneIndex on --level 345
		sudo chkconfig --list lxc_$ContainerPrefix$CloneIndex
		
		echo ''
		echo "=============================================="
		echo "Done: Create $CP$CloneIndex Onboot Service.   "
		echo "=============================================="
        	
		if [ $(SoftwareVersion $LXCVersion) -ge $(SoftwareVersion "2.1.0") ]
        	then
                	sudo lxc-update-config -c /var/lib/lxc/$CP$CloneIndex/config
        	fi

		CopyCompleted=$((CopyCompleted+1))
		CloneIndex=$((CloneIndex+1))

		sleep 5

		clear
	fi
done

echo ''
echo "=============================================="
echo "Container cloning completed.                  "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Creating OpenvSwitch files ...                "
echo "=============================================="
echo ''

sleep 5

# sudo /etc/network/openvswitch/create-ovs-sw-files-v2.sh $ContainerPrefix $NumCon $NewHighestContainerIndex $HighestContainerIndex
  sudo /etc/network/openvswitch/create-ovs-sw-files-v2.sh $ContainerPrefix $NumCon $CloneIndex

echo ''
echo "=============================================="
echo "Creating OpenvSwitch files complete.          "
echo "=============================================="

sleep 5

clear

if [ $(SoftwareVersion $LXCVersion) -ge $(SoftwareVersion "2.1.0") ]
then
        echo ''
        echo "=============================================="
        echo "Update config for LXC 2.1.0+                  "
        echo "=============================================="
        echo ''

        sudo lxc-update-config -c /var/lib/lxc/$SeedContainerName/config

	sleep 5

	clear

        echo ''
        echo "=============================================="
        echo "Done: Update config for LXC 2.1.0+            "
        echo "=============================================="
        echo ''
fi

sleep 5

clear

echo ''
echo "=============================================="
echo "Start Seed Container $SeedContainerName...    "
echo "=============================================="
echo ''

sudo lxc-start -n $SeedContainerName > /dev/null 2>&1
sleep 5
sudo lxc-ls -f

echo ''
echo "=============================================="
echo "Start Seed Container $SeedContainerName...    "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Start Clone Containers...                     "
echo "=============================================="
echo ''

function GetClonedContainers {
	sudo ls /var/lib/lxc | grep "ora$OracleRelease" | sort -V | sed 's/$/ /' | tr -d '\n' | sed 's/^[ \t]*//;s/[ \t]*$//'
}
ClonedContainers=$(GetClonedContainers)

for j in $ClonedContainers
do
	sudo lxc-start -n $j
	sleep 10
	sudo lxc-ls -f
	echo ''
done

echo "=============================================="
echo "Done: Start Clone Containers...               "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Next script to run: uekulele-services-5.sh    "
echo "=============================================="

sleep 5
