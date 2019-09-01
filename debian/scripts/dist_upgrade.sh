#!/bin/bash
# Slightly-uninteractive Dist Upgrade Debian 8 -> 9
# TODO: Make version agnostic (Oldest would be Wheezy) - DONE UNTIL BUSTER HAS BEEN FULLY TESTED
#       Make various processes into functions (This fixes readability and makes the script scalable for future upgrades) - DONE
#       Add MySQL conf fixes - DONE, WORKS.
#       Add additional parameter to email specific email.
#       Add Debian 10 path once OS is fully tested. - WAITING
#       Verify if MySQL fixes are even needed (sql may not be installed on server)
#       Automate Apache vHost and conf.d conversion - ADDED. NEEDS TESTING
#       Add Logging

# SUMMARY
#   This script is intended to be used to upgrade Debian to the latest stable version. As of 
#   17-7-19, the latest version is Buster. However, we are waiting on Buster to go through bug fixes before adding that upgrade path. 
#   This script will cover the upgrade process from 7.11 to 9.9. One upgrade will be done at a time, however the script
#   Should have the flexibility to be used with any version of 

# Display Shell output
set -x
set -v 

# Define Global Constants and Environment Variables
CURRENT_VERSION_NAME=$(lsb_release -c | cut -f 2)
CURRENT_VERSION_NUMBER="unknown"
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=mail
LOG_DIR="/root/upgrades/log"

function network_proc_snapshot () {
    if [ ! -d "/root/upgrades" ]; then
        echo "Upgrades dir not found. Creating..."
        mkdir /root/upgrades
    fi

    cd /root/upgrades
    echo "Gathering information about the running system..."
    
    dpkg --get-selections "*" > dpkg-$CURRENT_VERSION_NAME.txt
    ps auxf > ps-$CURRENT_VERSION_NAME.txt
    netstat -nap > netstat-$CURRENT_VERSION_NAME.txt
    ip a > ip-address-$CURRENT_VERSION_NAME.txt
    ip r > ip-route-$CURRENT_VERSION_NAME.txt
    iptables-save > iptables-$CURRENT_VERSION_NAME.txt
    
    echo "Created files: "
    echo " dpkg-$CURRENT_VERSION_NAME.txt, ps-$CURRENT_VERSION_NAME.txt, netstat-$CURRENT_VERSION_NAME.txt, \
    ip-a-$CURRENT_VERSION_NAME.txt, ip-r-$CURRENT_VERSION_NAME.txt, iptables-$CURRENT_VERSION_NAME.txt"
}

function apache22_24_conversion () {
    apache_root="/etc/apache2/sites-available"
    apache_root_old="/etc/apache2/conf.d"
    apache_vhosts_convert="/root/upgrades/vhosts-convert"

    if [[ ! -d "${apache_vhosts_convert}" ]]; then
        echo "VHost conversion directory not made. "
        mkdir -p ${apache_vhosts_convert}
    fi

    cd ${apache_vhosts_convert}
    if [[ ! -d "${apache_root_old}/vhosts.conf" ]]; then
        echo "vhosts.conf file doesn't exist at the conf.d directory"
    else
        csplit -f vhost ${apache_root_old}/vhosts.conf '/^<VirtualHost.*/' {*}

        if [[ -f ${apache_root_old}/vhosts-ssl.conf ]]; then
            csplit -f vhost-ssl ${apache_root_old}/vhosts-ssl.conf '/^<VirtualHost.*/' {*}
        fi


        for vhost in vhost*; do
            servername=$(grep -i ServerName $vhost | grep -v '^\s*#' | awk '{ print $2 }');
            conf_isSSL=0
            vhost_isSSL=0
            if [[ ${servername} == "" ]]; then
                continue
            fi

            if [[ -f "${apache_root}/${servername}.conf" ]]; then
                if grep -i ':443' ${apache_root}/${servername}.conf; then
                    conf_isSSL=1
                else
                    conf_isSSL=0
                fi

                if grep -i ':443' ${vhost}; then
                    vhost_isSSL=1
                else
                    vhost_isSSL=0
                fi

                if [[ ${vhost_isSSL} -ne ${conf_isSSL} ]]; then
                    echo "Adding host to existing configuration file..."
                    cat ${vhost} >> ${apache_root}/${servername}.conf
                    a2ensite ${servername}.conf
                elif [[ ${vhost_isSSL} -eq ${conf_isSSL} ]]; then
                    echo "Host entry exists. Skipping..."
                    continue
                else
                    echo "Unknown error occurred. Skipping $apache_root/$servername.conf"
                    continue
                fi
            else
                echo "Existing file not detected. Creating new conf file."
                cat ${vhost} >> ${apache_root}/${servername}.conf
                a2ensite ${servername}.conf
            fi
        done
        systemctl apache2 restart
    fi
}

function upgrade_check () {
    if [ $(echo "$?") -eq 0 ]; then
        echo "Upgrade of packages completed. Rerunning to be safe."
        apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --assume-yes --fix-broken --show-upgraded upgrade
        echo "Upgrade completed. Moving on..."
    else
        echo "Something went wrong with the package upgrade. Pausing the script, please open another shell and investigate the failure."
        read -rsp $'Press enter once all issues have been resolved: ' -n1 key
        echo ""
        echo "Rerunning apt upgrades..."
        apt-get update
        apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --assume-yes --fix-broken --show-upgraded upgrade
        if [ $(echo "$?") -ne 0 ]; then
            echo "Another error occurred during the apt upgrade. This is probably just MySQL upgrading. Exiting out of the script to be safe. "
            echo "Consider running: apt-get -o Dpkg::Options::='--force-overwrite' -f upgrade"
            read -rsp $'Press enter to exit the script: ' -n1 key
            echo "Upgrade failed on host $(hostname). Please review the server for what failed." | mail -s "Failed upgrade on $(hostname)" davis.damian@digitalwest.com
            exit 1
        fi
    fi
}

function fix_mysql () {
    echo "Updating mysql cnf info..."
    sed -i 's/log_slow_queries/#log_slow_queries/g' /etc/mysql/conf.d/dwni.cnf 
    find /etc/mysql/* -maxdepth 1 -type f -exec sed -i 's/thread_cache /thread_cache_size /g' {} \;
    find /etc/mysql/* -maxdepth 1 -type f -exec sed -i 's/key_buffer /key_buffer_size /g' {} \;
}

function completed_upgrade () {
    printf "The upgrade from $CURRENT_VERSION_NAME to $NEXT_VERSION_NAME has completed. \nHere is the information \ pulled from the start of the upgrade in case there are any issues:\n $(cat /root/upgrades/dpkg-$CURRENT_VERSION_NAME.txt /root/upgrades/ip-address-$CURRENT_VERSION_NAME.txt ip-route-$CURRENT_VERSION_NAME.txt /root/upgrades/iptables-$CURRENT_VERSION_NAME.txt)\n" | mail -s "Upgrades for $(hostname) Completed" davis.damian@digitalwest.com
}

function debian_pre_upgrade_to_buster () {
    sed -i 's/deb/#deb/g' /etc/apt/sources.list.d/*
    cp -a /etc/apt/sources.list /root/upgrades/sources.list.bak.stretch

    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade
    cat > /etc/apt/sources.list << "EOF"
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main

deb http://deb.debian.org/debian-security/ buster/updates main
deb-src http://deb.debian.org/debian-security/ buster/updates main

deb http://deb.debian.org/debian buster-updates main
deb-src http://deb.debian.org/debian buster-updates main
EOF
}

function debian_pre_upgrade_to_stretch () {
    # Ignore all supplementary repos for now
    sed -i 's/deb/#deb/g' /etc/apt/sources.list.d/*
    cp -a /etc/apt/sources.list ~/sources.list.bak.jessie

    # Update all packages before dist upgrade
    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade
    cat > /etc/apt/sources.list << "EOF"
deb http://mirrors.kernel.org/debian/ stretch main contrib non-free
deb-src http://mirrors.kernel.org/debian/ stretch main contrib non-free

deb http://security.debian.org/ stretch/updates main contrib non-free
deb-src http://security.debian.org/ stretch/updates main contrib non-free

# stretch-updates, previously known as 'volatile'
deb http://mirrors.kernel.org/debian/ stretch-updates main contrib non-free
deb-src http://mirrors.kernel.org/debian/ stretch-updates main contrib non-free
EOF
}

function debian_pre_upgrade_to_jessie () {
    sed -i 's/deb/#deb/g' /etc/apt/sources.list.d/*
    cp -a /etc/apt/sources.list ~/sources.list.bak.$CURRENT_VERSION_NAME
    cat > /etc/apt/sources.list << "EOF"
deb http://archive.debian.org/debian wheezy main
EOF

    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade

    cat > /etc/apt/sources.list << "EOF"
deb http://deb.debian.org/debian/ jessie main contrib non-free
deb-src http://deb.debian.org/debian/ jessie main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main contrib non-free
EOF
}

function debian_upgrade_to_jessie () {
    debian_pre_upgrade_to_jessie
    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade
    upgrade_check

    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded dist-upgrade

    if [[ "$(dpkg-query -l apache2)" ]]; then
        apache22_24_conversion
    else
        echo "Apache not found on this host. Continuing..."
    fi

    echo "Rerunning dist-upgrade again to make sure no packages were missed..."
    sleep 5
    apt-get -o Dpkg::Options::="--force-confold" --assume-yes --fix-broken --show-upgraded dist-upgrade
    completed_upgrade
    reboot
}

function debian_upgrade_to_stretch () {

    debian_pre_upgrade_to_stretch
    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade
    upgrade_check

    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded dist-upgrade
    if [[ "$(dpkg -l mysql-server)" ]]; then
        fix_mysql
    else
        echo "No SQL installation installed. Skipping MySQL fixes..."
    fi
    echo "Rerunning dist-upgrade again to make sure no packages were missed"
    sleep 5
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded dist-upgrade
    completed_upgrade
    salt_min_beacon_reactor_gen
    reboot
}

function debian_upgrade_to_buster () {
    debian_pre_upgrade_to_buster
    apt-get update
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded upgrade
    upgrade_check

    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded dist-upgrade
    echo "Rerunning dist-upgrade again to make sure no packages were missed"
    sleep 5
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  --assume-yes --fix-broken --show-upgraded dist-upgrade
    completed_upgrade
    salt_min_beacon_reactor_gen
    reboot
}

function salt_min_beacon_reactor_gen () {
    echo "upgrade_complete: True" > /etc/debian-${NEXT_VERSION_NAME}-upgrade 

    echo "beacons:
  inotify:
    - files:
      /etc/debian-${NEXT_VERSION_NAME}-upgrade:
        mask:
          - modify
    - disable_during_state_run: True" >> /etc/salt/minion.d/beacons.conf 
}

function main_upgrade () {
    case $CURRENT_VERSION_NAME in
        wheezy)
            CURRENT_VERSION_NUMBER="7"
            NEXT_VERSION_NAME="jessie"
            NEXT_VERSION_NUMBER="8"
            ;;
        jessie)
            CURRENT_VERSION_NUMBER="8"
            NEXT_VERSION_NAME="stretch"
            NEXT_VERSION_NUMBER="9"
            ;;
        stretch)
            CURRENT_VERSION_NUMBER="9"
            NEXT_VERSION_NAME="buster"
            NEXT_VERSION_NUMBER="10"
            ;;
        *)
            echo "An unknown error occurred. The version of Debian is likely too old. Make sure you are using Debian 7 at the earliest."
            exit 1
    esac

    echo -en "Upgrading 'Debian $CURRENT_VERSION_NAME ($CURRENT_VERSION_NUMBER)' to "
    echo "'Debian $NEXT_VERSION_NAME ($NEXT_VERSION_NUMBER)'"

    network_proc_snapshot
    debian_upgrade_to_$NEXT_VERSION_NAME
}

###         RUN         ###
main_upgrade
###         STOP        ###
