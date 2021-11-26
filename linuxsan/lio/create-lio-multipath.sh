#!/bin/bash
#
#    Copyright 2015-2021 Gilbert Standen
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
#    v7.0-ELENA-beta    GLS 20210428 Enterprise LXD Edition New AMIDE

#    Note that this software builds a containerized DNS DHCP solution (bind9 / isc-dhcp-server).
#    The nameserver should NOT be the name of an EXISTING nameserver but an arbitrary name because this software is CREATING a new LXC-containerized nameserver.
#    The domain names can be arbitrary fictional names or they can be a domain that you actually own and operate.
#    There are two domains and two networks because the "seed" LXC containers are on a separate network from the production LXC containers.
#    If the domain is an actual domain, you will need to change the subnet using the subnets feature of Orabuntu-LXC

if [ -e /sys/hypervisor/uuid ]
then
        function CheckAWS {
                cat /sys/hypervisor/uuid | cut -c1-3 | grep -c ec2
        }
        AWS=$(CheckAWS)
else
        AWS=0
fi

StorageOwner=$1
if [ -z $1 ]
then
	StorageOwner=grid
fi

StorageOwnerGid=$2
if [ -z $2 ]
then
	StorageOwnerGid=1098
fi

StorageGroup=$3
if [ -z $3 ]
then
	StorageGroup=asmadmin
fi

StorageGroupGid=$4
if [ -z $4 ]
then
	StorageGroupGid=1100
fi

Mode=$5
if [ -z $5 ]
then
	Mode="0660"
fi

StoragePrefix=$7
if [ -z $7 ]
then
	StoragePrefix=asm
fi

ContainerName=$6
if [ -z $6 ]
then
	ContainerName=$StoragePrefix_luns
fi

OpType=$8
if [ -z $8 ]
then
	OpType=new
fi

Release=$9

SUDO_PREFIX=${10}
if [ -z ${10} ]
then
        SUDO_PREFIX=sudo
fi

echo ''
echo "=============================================="
echo "Verify $StorageOwner user...                  "
echo "=============================================="
echo ''

sudo useradd  -u    $StorageOwnerGid $StorageOwner		>/dev/null 2>&1
sudo groupadd -g    $StorageGroupGid $StorageGroup        	>/dev/null 2>&1
sudo usermod  -a -G $StorageGroup    $StorageOwner  		>/dev/null 2>&1

id $StorageOwner

echo ''
echo "=============================================="
echo "Done: Verify $StorageOwner user.              "
echo "=============================================="

sleep 5

clear

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
echo $LinuxFlavors | sed 's/^[ \t]//;s/[ \t]$//' | sed 's/\!//'
}
LinuxFlavor=$(TrimLinuxFlavors)

if [ $LinuxFlavor = 'Ubuntu' ] || [ $LinuxFlavor = 'Debian' ] || [ $LinuxFlavor = 'Pop_OS' ]
then
	echo ''
	echo "===================================================="
	echo "Create multipath.conf for $LinuxFlavor Linux...     "
	echo "===================================================="
	echo ''

	sleep 5

	attrs='ATTRS{rev}|ATTRS{model}|ATTRS{vendor}'

	if   [ $OpType = 'new' ]
	then
		echo '' 				 > multipath.conf
		echo 'blacklist {' 			>> multipath.conf
		if [ $AWS -eq 1 ]
		then
			echo '#   devnode      "sd[a]$"' 	>> multipath.conf
		else
			echo '    devnode      "sd[a]$"' 	>> multipath.conf
		fi
	elif [ $OpType = 'add' ]
	then
		sudo cp -p /etc/multipath.conf multipath.conf
	fi

	function GetDevNode {
		sudo ls /dev/sd* | sed 's/$/ /' | tr -d '\n'
	}
	DevNode=$(GetDevNode)

        if [ -f 99-$StorageOwner.rules ]
        then
                sudo rm 99-$StorageOwner.rules
        fi

	for k in $DevNode
	do
		function GetVendor {
		sudo udevadm info -a -p  $(udevadm info -q path -n $k) | egrep 'ATTRS{vendor}' | grep -v '0x' | sed 's/  *//g' | rev | cut -f1 -d'=' | sed 's/"//g' | rev | sed 's/$/_DEVICE/'
		}
		Vendor=$(GetVendor)
 		function GetProduct {
 		sudo udevadm info -a -p  $(udevadm info -q path -n $k) | egrep 'ATTRS{model}' | grep -v '0x' | sed 's/  *//g' | rev | cut -f1 -d'=' | rev
 		}
 		Product=$(GetProduct)
		function CheckProductExist {
		cat multipath.conf | grep $Product | rev | cut -f1 -d' ' | rev | sort -u | wc -l
		}
		ProductExist=$(CheckProductExist)
		function GetExistId {
		sudo /lib/udev/scsi_id -g -u -d $k
		}
		ExistId=$(GetExistId)
		if [ "$Vendor" != "SCST_FIO_DEVICE" ] && [ "$ProductExist" -eq 0 ] && [ ! -z $ExistId ]
		then
			ExistId=$(GetExistId)
			function CheckIdExist {
			grep -c $ExistId multipath.conf
			}
			IdExist=$(CheckIdExist)
			if [ "$IdExist" -eq 0 ]
			then
				if [ $OpType = 'new' ]
				then
					sudo /lib/udev/scsi_id -g -u -d $k | sed 's/^/    wwid         "/' | sed 's/$/"/' 								     >> multipath.conf
				fi
			fi
			if [ $OpType = 'new' ]
			then
			  echo '    device {' 																		     >> multipath.conf
			  sudo udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep vendor | cut -f3 -d'=' | sed 's/  *//g' | sed 's/^/        vendor   /' >> multipath.conf
			  sudo udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep model  | cut -f3 -d'=' | sed 's/  *//g' | sed 's/^/        product  /' >> multipath.conf
			# sudo udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep rev    | cut -f3 -d'=' | sed 's/  *//g' | sed 's/^/        revision /' >> multipath.conf
			  echo '    }' 																			     >> multipath.conf
			fi
		fi
	done

	if [ $OpType = 'new' ]
	then
		echo '}' 										>> multipath.conf
		echo 'defaults {' 									>> multipath.conf
		echo '    user_friendly_names  yes' 							>> multipath.conf
		echo '}' 										>> multipath.conf
		echo 'devices {' 									>> multipath.conf
		echo '    device {' 									>> multipath.conf
		echo '    vendor               "SCST_FIO"' 						>> multipath.conf
		echo "    product             \"$StoragePrefix*\"" 					>> multipath.conf
		echo '    revision             "310"' 							>> multipath.conf
		echo '    path_grouping_policy group_by_serial' 					>> multipath.conf
		echo '    getuid_callout       "/lib/udev/scsi_id --whitelisted --device=/dev/%n"' 	>> multipath.conf
		echo '    hardware_handler     "0"' 							>> multipath.conf
		echo '    features             "1 queue_if_no_path"' 					>> multipath.conf
		echo '    fast_io_fail_tmo     5' 							>> multipath.conf
		echo '    dev_loss_tmo         30' 							>> multipath.conf
		echo '    failback             immediate' 						>> multipath.conf
		echo '    rr_weight            uniform' 						>> multipath.conf
		echo '    no_path_retry        fail' 							>> multipath.conf
		echo '    path_checker         tur' 							>> multipath.conf
		echo '    rr_min_io            4' 							>> multipath.conf
		echo '    path_selector        "round-robin 0"' 					>> multipath.conf
		echo '    }' 										>> multipath.conf
		echo '}' 										>> multipath.conf
		echo 'multipaths {' 									>> multipath.conf
	fi

	function GetLunName {
	cat /etc/scst.conf | grep LUN | rev | cut -f1 -d' ' | rev | sed 's/$/ /' | tr -d '\n'
	}
	LunName=$(GetLunName)

	for i in $LunName
	do
		function GetDevNode {
			sudo ls /dev/sd* | sed 's/$/ /' | tr -d '\n'
		}
		DevNode=$(GetDevNode)
		for j in $DevNode
		do
			function GetModelName {
			  sudo udevadm info -a -p  $(udevadm info -q path -n $j) | egrep 'ATTRS{model}' | sed 's/  *//g' | rev | cut -f1 -d'=' | sed 's/"//g' | rev | sed 's/^[ \t]*//;s/[ \t]*$//' | grep $i 
			}
			function CheckEntryExist {
			  cat multipath.conf | grep $i
			}
			EntryExist=$(CheckEntryExist)
			ModelName=$(GetModelName)

			if [ "$ModelName" = "$i" ] && [ -z "$EntryExist" ]
			then
				function Getwwid {
					sudo /lib/udev/scsi_id -g -u -d $j
				}
				wwid=$(Getwwid)

				if   [ $OpType = 'new' ]
				then
					echo "     multipath {" 					>> multipath.conf
					echo "         wwid $wwid" 					>> multipath.conf
					echo "         alias $i" 					>> multipath.conf
					echo "     }" 							>> multipath.conf
				elif [ $OpType = 'add' ]
				then
					echo "     multipath {" 					>> add_paths.conf
					echo "         wwid $wwid" 					>> add_paths.conf
					echo "         alias $i" 					>> add_paths.conf
					echo "     }" 							>> add_paths.conf
				fi

				cp -p 99-StorageOwner.rules.template 					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/wwid/$wwid/g" 						99-$StorageOwner.rules.$wwid.$i
				sed -i "s/FriendlyName/$i/g" 						99-$StorageOwner.rules.$wwid.$i
				sed -i "s/ContainerName/$ContainerName/g"				99-$StorageOwner.rules.$wwid.$i
				sed -i "s/StorageOwner/$StorageOwner/g"					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/StorageGroup/$StorageGroup/g"					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/Mode/$Mode/g"							99-$StorageOwner.rules.$wwid.$i

				cat 99-$StorageOwner.rules.$wwid.$i 					>> 99-$StorageOwner.rules
			fi
		done
	done

	if [ $OpType = 'new' ]
	then
		echo '}' 										>> multipath.conf
	fi

	# GLS 20151126 Added function to get kernel version of running kernel to support linux 4.x kernels in Ubuntu Wily Werewolf etc.

	function GetRunningKernelVersion {
		uname -r | cut -f1-2 -d'.'
	}
	RunningKernelVersion=$(GetRunningKernelVersion)

	# GLS 20151126 Added function to get kernel directory path for running kernel version to support linux 4.x and linux 3.x kernels etc.

	function GetKernelDirectoryPath {
	uname -a | cut -f3 -d' ' | cut -f1 -d'-' | cut -f1 -d'.' | sed 's/^/linux-/'
	}
	KernelDirectoryPath=$(GetKernelDirectoryPath)

	if [ $KernelDirectoryPath = 'linux-4' ]
	then
	sed -i 's/revision "/# revision "/' multipath.conf
	fi

	cat multipath.conf

	echo ''
	echo "===================================================="
	echo "File multipath.conf created for $LinuxFlavor Linux  "
	echo "===================================================="
	echo ''

	sleep 5

	clear

	echo ''
	echo "===================================================="
	echo "Backup old /etc/multipath.conf and install new...   "
	echo "===================================================="
	echo ''

	export DATEXT=`date +'%y%m%d_%H%M%S'`
	
	if [ -f /etc/multipath.conf ]
	then
		sudo cp -p /etc/multipath.conf /etc/multipath.conf.pre-scst.bak.$DATEXT
	fi
	if   [ $OpType = 'new' ]
	then
		sudo cp -p multipath.conf /etc/multipath.conf
	elif [ $OpType = 'add' ]
	then
		echo ''
		echo "Add these multipaths to the /etc/multipath.conf manually"
		echo ''
		if [ -f add-paths.conf ]
		then
			cat add-paths.conf
		fi
	fi

	sudo ls -l /etc/multipath.conf*
	if [ -f add-paths.conf ]
	then
		sudo ls -l  add-paths.conf*a
	fi

	echo ''
	echo "===================================================="
	echo "Backup complete.                                    "
	echo "===================================================="

	sleep 5

	clear

	echo ''
	echo "===================================================="
	echo "Install 99-$StorageOwner.rules file (backup old first)...  "
	echo "===================================================="

	if [ -f /etc/udev/rules.d/99-$StorageOwner.rules ]
	then
		sudo cp -p /etc/udev/rules.d/99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules.pre-scst.bak
		sudo cat 99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules > new
		sudo mv new 99-$StorageOwner.rules
	else
		sudo cp -p 99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules
		sudo chmod 755 /etc/udev/rules.d/99-$StorageOwner.rules
	fi
	
	sudo sed -i "s/StoragePrefix/$StoragePrefix/g" /etc/udev/rules.d/99-$StorageOwner.rules	
	cat /etc/udev/rules.d/99-$StorageOwner.rules

	echo ''
	echo "===================================================="
	echo "Install 99-$StorageOwner.rules file completed.             "
	echo "===================================================="
	
	sleep 5

	clear

	if [ $OpType = 'new' ]
	then
		echo ''
		echo "===================================================="
		echo "Restart multipath service...                        "
		echo "===================================================="
		echo ''

		sudo service multipath-tools stop
		sudo multipath -F
		sudo service multipath-tools start

		echo ''
		echo "===================================================="
		echo "Restart multipath service completed.                "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Check $StorageOwner SCST LUNs present and using aliases... "
		echo "===================================================="
		echo ''

		ls -l /dev/mapper | grep "$StoragePrefix"*

		echo ''
		echo "===================================================="
		echo "SCST LUNs present and using aliases.                "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  ls -l /dev/mapper/$StoragePrefix  "
		echo "===================================================="
		echo ''

		ls -l /dev/mapper/"$StoragePrefix"*

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN: sudo multipath -ll -v2             "
		echo "===================================================="
		echo ''

		sudo multipath -ll -v2

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN: sudo scstadmin -list_group         "
		echo "===================================================="
		echo ''

		scstadmin -list_group

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify: ls-l /dev/dm* ($StorageOwner:$StorageGroup) " 
		echo "===================================================="
		echo ''

 		sudo ls -l /dev/dm*

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SAN: cat /etc/udev/rules.d/99-$StorageOwner.rules   "
		echo "===================================================="
		echo ''

		cat /etc/udev/rules.d/99-$StorageOwner.rules 

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="
	fi
fi

if [ $LinuxFlavor = 'CentOS' ] || [ $LinuxFlavor = 'Red' ] || [ $LinuxFlavor = 'Fedora' ] || [ $LinuxFlavor = 'Oracle' ]
then
	echo ''
	echo "===================================================="
	echo "Create multipath.conf for $LinuxFlavor Linux...     "
	echo "===================================================="
	echo ''

	if [ $LinuxFlavor = 'Fedora' ]
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
	fi

	attrs='ATTRS{rev}|ATTRS{model}|ATTRS{vendor}'

	if   [ $OpType = 'new' ]
	then
		echo '' 				 > multipath.conf
		echo 'blacklist {' 			>> multipath.conf
		echo '    devnode      "sd[a]$"' 	>> multipath.conf
	elif [ $OpType = 'add' ]
	then
		sudo cp -p /etc/multipath.conf multipath.conf
	fi

	function GetDevNode {
	ls /dev/sd* | sed 's/$/ /' | tr -d '\n'
	}
	DevNode=$(GetDevNode)

        if [ -f /etc/udev/rules.d/99-$StorageOwner.rules ]
        then
                sudo mv /etc/udev/rules.d/99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules.pre-orabuntu.bak
        fi

	j=1
	for k in $DevNode
	do
		function GetVendor {
			udevadm info -a -p  $(udevadm info -q path -n $k) | egrep 'ATTRS{vendor}' | grep -v '0x' | sed 's/  *//g' | rev | cut -f1 -d'=' | sed 's/"//g' | rev | sed 's/$/_DEVICE/'
		}
		Vendor=$(GetVendor)
 		function GetProduct {
 			udevadm info -a -p  $(udevadm info -q path -n $k) | egrep 'ATTRS{model}' | grep -v '0x' | sed 's/  *//g' | rev | cut -f1 -d'=' | rev
 		}
 		Product=$(GetProduct)
		function CheckProductExist {
			cat multipath.conf | grep $Product | rev | cut -f1 -d' ' | rev | sort -u | wc -l
		}
		ProductExist=$(CheckProductExist)
		function GetExistId {
	 		/lib/udev/scsi_id -g -u -d $k
		}
		ExistId=$(GetExistId)
		if [ "$Vendor" != "SCST_FIO_DEVICE" ] && [ "$ProductExist" -eq 0 ] && [ ! -z $ExistId ]
		then
			ExistId=$(GetExistId)
			function CheckIdExist {
			grep -c $ExistId multipath.conf
			}
			IdExist=$(CheckIdExist)
			if [ "$IdExist" -eq 0 ]
			then
				if [ $OpType = 'new' ]
				then
					 /lib/udev/scsi_id -g -u -d $k | sed 's/^/    wwid         "/' | sed 's/$/"/' 								>> multipath.conf
				fi
			fi
			if [ $OpType = 'new' ] && [ $j -eq 1 ]
			then
			  echo '    device {' 																	        				 	>> multipath.conf
			  udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep vendor | cut -f3 -d'=' | sed 's/  *//g' 					| sed 's/^/        vendor   /'  >> multipath.conf
			  udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep model  | cut -f3 -d'=' | sed 's/"$//' | sed 's/[ \t]*$//' | sed 's/$/"/'	| sed 's/^/        product  /' 	>> multipath.conf
			# udevadm info -a -p  $(udevadm info -q path -n $k) | egrep "$attrs" | grep -v 0x | grep rev    | cut -f3 -d'=' | sed 's/  *//g' 					| sed 's/^/        revision /'  >> multipath.conf
			  echo '    }' 																		        				 	>> multipath.conf
			fi
		fi
		j=$((j+1))
	done

	if [ $OpType = 'new' ]
	then
		echo '}' 											>> multipath.conf
		echo 'defaults {' 										>> multipath.conf
		echo '    user_friendly_names  yes' 								>> multipath.conf
		echo '}' 											>> multipath.conf
		echo 'devices {' 										>> multipath.conf
		echo '    device {' 										>> multipath.conf
		echo '    vendor               "SCST_FIO"' 							>> multipath.conf
		echo "    product              \"$StoragePrefix*\"" 						>> multipath.conf
	
		function GetLinuxRelease {
			cat /etc/redhat-release | grep -c 'release 7'
		}
		LinuxRelease=$(GetLinuxRelease)

		if [ $LinuxRelease -eq 1 ]
		then
			echo '#   revision             "310"' 							>> multipath.conf
			echo '#   getuid_callout       "/lib/udev/scsi_id --whitelisted --device=/dev/%n"' 	>> multipath.conf
		else
			echo '    getuid_callout       "/lib/udev/scsi_id --whitelisted --device=/dev/%n"'	>> multipath.conf
			echo '    revision             "310"'							>> multipath.conf
		fi

		echo '    path_grouping_policy group_by_serial' 						>> multipath.conf
		echo '    hardware_handler     "0"' 								>> multipath.conf
		echo '    features             "1 queue_if_no_path"' 						>> multipath.conf
		echo '    fast_io_fail_tmo     5' 								>> multipath.conf
		echo '    dev_loss_tmo         30' 								>> multipath.conf
		echo '    failback             immediate' 							>> multipath.conf
		echo '    rr_weight            uniform' 							>> multipath.conf
		echo '    no_path_retry        fail' 								>> multipath.conf
		echo '    path_checker         tur' 								>> multipath.conf
		echo '    rr_min_io            4' 								>> multipath.conf
		echo '    path_selector        "round-robin 0"' 						>> multipath.conf
		echo '    }' 											>> multipath.conf
		echo '}' 											>> multipath.conf
		echo 'multipaths {' 										>> multipath.conf
	fi

	function GetLunName {
	cat /etc/scst.conf | grep LUN | rev | cut -f1 -d' ' | rev | sed 's/$/ /' | tr -d '\n'
	}
	LunName=$(GetLunName)

	for i in $LunName
	do
		function GetDevNode {
			ls /dev/sd* | sed 's/$/ /' | tr -d '\n'
		}
		DevNode=$(GetDevNode)
		for j in $DevNode
		do
			function GetModelName {
			  udevadm info -a -p  $(udevadm info -q path -n $j) | egrep 'ATTRS{model}' | sed 's/  *//g' | rev | cut -f1 -d'=' | sed 's/"//g' | rev | sed 's/^[ \t]*//;s/[ \t]*$//' | grep $i 
			}

			function CheckEntryExist {
			  cat multipath.conf | grep $i
			}

			EntryExist=$(CheckEntryExist)
			ModelName=$(GetModelName)

			if [ "$ModelName" = "$i" ] && [ -z "$EntryExist" ]
			then
				function Getwwid {
					/lib/udev/scsi_id -g -u -d $j
				}
				wwid=$(Getwwid)

				if   [ $OpType = 'new' ]
				then
					echo "     multipath {" 					>> multipath.conf
					echo "         wwid $wwid" 					>> multipath.conf
					echo "         alias $i" 					>> multipath.conf
					echo "     }" 							>> multipath.conf
				elif [ $OpType = 'add' ]
				then
					echo "     multipath {" 					>> add_paths.conf
					echo "         wwid $wwid" 					>> add_paths.conf
					echo "         alias $i" 					>> add_paths.conf
					echo "     }" 							>> add_paths.conf
				fi
			
				cp -p 99-StorageOwner.rules.template 					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/wwid/$wwid/g" 						99-$StorageOwner.rules.$wwid.$i
				sed -i "s/FriendlyName/$i/g" 						99-$StorageOwner.rules.$wwid.$i
				sed -i "s/ContainerName/$ContainerName/g"				99-$StorageOwner.rules.$wwid.$i
				sed -i "s/StorageOwner/$StorageOwner/g"					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/StorageGroup/$StorageGroup/g"					99-$StorageOwner.rules.$wwid.$i
				sed -i "s/Mode/$Mode/g"							99-$StorageOwner.rules.$wwid.$i

				cat 99-$StorageOwner.rules.$wwid.$i 					>> 99-$StorageOwner.rules
			fi
		done
	done

	if [ $OpType = 'new' ]
	then
		echo '}' 										>> multipath.conf
	fi

	# GLS 20151126 Added function to get kernel version of running kernel to support linux 4.x kernels in Ubuntu Wily Werewolf etc.

	function GetRunningKernelVersion {
		uname -r | cut -f1-2 -d'.'
	}
	RunningKernelVersion=$(GetRunningKernelVersion)

	# GLS 20151126 Added function to get kernel directory path for running kernel version to support linux 4.x and linux 3.x kernels etc.

	function GetKernelDirectoryPath {
		uname -a | cut -f3 -d' ' | cut -f1 -d'-' | cut -f1 -d'.' | sed 's/^/linux-/'
	}
	KernelDirectoryPath=$(GetKernelDirectoryPath)

	if [ $KernelDirectoryPath = 'linux-4' ]
	then
		sed -i 's/revision "/# revision "/' multipath.conf
	fi

	cat multipath.conf

	echo ''	
	echo "===================================================="
	echo "File multipath.conf created for $LinuxFlavor Linux  "
	echo "===================================================="

	sleep 5

	clear
	
	echo ''
	echo "===================================================="
	echo "Backup /etc/multipath.conf & install new...         "
	echo "===================================================="
	echo ''

	export DATEXT=`date +'%y%m%d_%H%M%S'`
	
	if [ -f /etc/multipath.conf ]
	then
		sudo cp -p /etc/multipath.conf /etc/multipath.conf.pre-scst.bak.$DATEXT
	fi

	if   [ $OpType = 'new' ]
	then
		sudo cp -p multipath.conf /etc/multipath.conf
	elif [ $OpType = 'add' ]
	then
		echo ''
		echo "Add these multipaths to the /etc/multipath.conf manually"
		echo ''
		if [ -f add-paths.conf ]
		then
			cat add-paths.conf
		fi
	fi

	sudo ls -l /etc/multipath.conf*
	if [ -f add-paths.conf ]
	then
		sudo ls -l  add-paths.conf*
	fi

	echo ''
	echo "===================================================="
	echo "Backup /etc/multipath.conf & install new...         "
	echo "===================================================="

	sleep 5

	clear
	
	echo ''
	echo "===================================================="
	echo "Install 99-$StorageOwner.rules file (backup old first)...  "
	echo "===================================================="

	if [ -f /etc/udev/rules.d/99-$StorageOwner.rules ]
	then
		sudo cp -p /etc/udev/rules.d/99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules.pre-scst.bak
		sudo cat 99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules > new
		sudo mv new 99-$StorageOwner.rules
	else
		sudo cp -p 99-$StorageOwner.rules /etc/udev/rules.d/99-$StorageOwner.rules
	fi

	sudo sed -i "s/StoragePrefix/$StoragePrefix/g" /etc/udev/rules.d/99-$StorageOwner.rules	
	cat /etc/udev/rules.d/99-$StorageOwner.rules

	echo "===================================================="
	echo "Install 99-$StorageOwner.rules file completed.             "
	echo "===================================================="
	
	sleep 5

	clear

	if [ $OpType = 'new' ]
	then
		echo ''
		echo "===================================================="
		echo "Restart multipath service...                        "
		echo "===================================================="
		echo ''

		sudo service multipathd stop
		sudo service multipath -F
		sudo service multipathd start

		echo ''
		echo "===================================================="
		echo "Restart multipath service completed.                "
		echo "===================================================="

		sleep 5

		clear
	
		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  ls -l <storage_locations>         "
		echo "===================================================="
		echo ''

		ls -l /dev/mapper/"$StoragePrefix"*
		echo  ''
		ls -l /dev/"$StoragePrefix"
		echo '' 
		ls -l /dev/$ContainerName

		echo ''
		echo "===================================================="
		echo "Done:  Verify SCST SAN:  ls -l <storage_locations>  "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN: sudo ls -l /dev/dm*                "
		echo "===================================================="
		echo ''

 		sudo ls -l /dev/dm*

		echo ''
		echo "===================================================="
		echo "Done: Verify SCST SAN: ($StorageOwner:$StorageGroup)"
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN: sudo multipath -ll -v2             "
		echo "===================================================="
		echo ''

		sudo multipath -ll -v2

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN: sudo scstadmin -list_group         "
		echo "===================================================="
		echo ''

		scstadmin -list_group

		echo ''
		echo "===================================================="
		echo "Verify SCST SAN:  Done.                             "
		echo "===================================================="

		sleep 5

		clear

#		GLS 20210220
#		Release is now passed in from create-scst.sh script.

#               function GetRedHatVersion {
#                       cat /etc/redhat-release | sed 's/ Linux//' | cut -f1 -d'.' | rev | cut -f1 -d' '
#               }
#               RedHatVersion=$(GetRedHatVersion)
#               Release=$RedHatVersion
	
		if [ $Release -eq 6 ]
		then	
			echo ''
			echo "===================================================="
			echo "Set Onboot Services...                              "
			echo "===================================================="
			echo ''

			chkconfig scst on
			chkconfig multipathd on
			chkconfig iscsi on
			# chkconfig iscsid on
			sudo sh -c "echo 'service iscsi start' >> /etc/rc.local"

			echo ''
			echo "===================================================="
			echo "Done: Set Onboot Services...                        "
			echo "===================================================="

			sleep 5

			clear
		fi
	fi
fi

echo ''
echo "====================================================="
echo "SCST SAN Configuration Complete.                     "
echo "====================================================="
echo ''

sleep 5

clear

echo "====================================================="
echo "To uninstall this software run this script:          "
echo "                                                     "
echo "create-scst-uninstall.sh                             "
echo "                                                     "
echo "====================================================="
echo ''

