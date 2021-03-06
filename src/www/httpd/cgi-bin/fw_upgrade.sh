#!/bin/sh

SONOFF_HACK_PREFIX="/mnt/mmc/sonoff-hack"

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/mmc/sonoff-hack/lib
export PATH=$PATH:/mnt/mmc/sonoff-hack/bin:/mnt/mmc/sonoff-hack/sbin:/mnt/mmc/sonoff-hack/usr/bin:/mnt/mmc/sonoff-hack/usr/sbin

NAME="$(echo $QUERY_STRING | cut -d'=' -f1)"
VAL="$(echo $QUERY_STRING | cut -d'=' -f2)"

if [ "$NAME" != "get" ] ; then
    exit
fi

if [ "$VAL" == "info" ] ; then
    printf "Content-type: application/json\r\n\r\n"

    FW_VERSION=`cat /mnt/mmc/sonoff-hack/version`
    LATEST_FW=`/mnt/mmc/sonoff-hack/usr/bin/wget -O -  https://api.github.com/repos/roleoroleo/sonoff-hack/releases/latest 2>&1 | grep '"tag_name":' | sed -r 's/.*"([^"]+)".*/\1/'`

    printf "{\n"
    printf "\"%s\":\"%s\",\n" "fw_version"      "$FW_VERSION"
    printf "\"%s\":\"%s\"\n" "latest_fw"       "$LATEST_FW"
    printf "}"

elif [ "$VAL" == "upgrade" ] ; then

    FREE_SD=$(df /mnt/mmc/ | grep mmc | awk '{print $4}')
    if [ -z "$FREE_SD" ]; then
        printf "Content-type: text/html\r\n\r\n"
        printf "No SD detected."
        exit
    fi

    if [ $FREE_SD -lt 100000 ]; then
        printf "Content-type: text/html\r\n\r\n"
        printf "No space left on SD."
        exit
    fi

    rm -rf /mnt/mmc/.fw_upgrade
    mkdir -p /mnt/mmc/.fw_upgrade
    cd /mnt/mmc/.fw_upgrade
    rm -rf /mnt/mmc/.fw_upgrade.conf
    mkdir -p /mnt/mmc/.fw_upgrade.conf

    MODEL=$(cat /mnt/mtd/ipc/cfg/config_cst.cfg | grep model | cut -d'=' -f2 | cut -d'"' -f2)
    FW_VERSION=`cat /mnt/mmc/sonoff-hack/version`
    LATEST_FW=`/mnt/mmc/sonoff-hack/usr/bin/wget -O -  https://api.github.com/repos/roleoroleo/sonoff-hack/releases/latest 2>&1 | grep '"tag_name":' | sed -r 's/.*"([^"]+)".*/\1/'`
    if [ "$FW_VERSION" == "$LATEST_FW" ]; then
        printf "Content-type: text/html\r\n\r\n"
        printf "No new firmware available."
        exit
    fi

    $SONOFF_HACK_PREFIX/usr/bin/wget https://github.com/roleoroleo/sonoff-hack/releases/download/$LATEST_FW/${MODEL}_${LATEST_FW}.tgz
    if [ ! -f ${MODEL}_${LATEST_FW}.tgz ]; then
        printf "Content-type: text/html\r\n\r\n"
        printf "Unable to download firmware file."
        exit
    fi

    # Backup configuration
    cp -f $SONOFF_HACK_PREFIX/etc/*.conf /mnt/mmc/.fw_upgrade.conf/
    if [ -f $SONOFF_HACK_PREFIX/etc/hostname ]; then
        cp -f $SONOFF_HACK_PREFIX/etc/hostname /mnt/mmc/.fw_upgrade.conf/
    fi
    cp -rf $SONOFF_HACK_PREFIX/etc/dropbear /mnt/mmc/.fw_upgrade.conf/

    # Killall processes
    killall wsdd
    killall onvif_srvd
    killall mqtt-sonoff
    killall pure-ftpd
    killall dropbear
    sleep 1

    # Copy new hack
    $SONOFF_HACK_PREFIX/bin/tar zxvf ${MODEL}_${LATEST_FW}.tgz
    rm ${MODEL}_${LATEST_FW}.tgz
    rm -rf $SONOFF_HACK_PREFIX.old
    mv $SONOFF_HACK_PREFIX $SONOFF_HACK_PREFIX.old
    mv -f * ..

    # Restore configuration
    cp -f /mnt/mmc/.fw_upgrade.conf/*.conf $SONOFF_HACK_PREFIX/etc/
    if [ -f /mnt/mmc/.fw_upgrade.conf/hostname ]; then
        cp -f /mnt/mmc/.fw_upgrade.conf/hostname $SONOFF_HACK_PREFIX/etc/hostname
    fi
    cp -rf /mnt/mmc/.fw_upgrade.conf/dropbear $SONOFF_HACK_PREFIX/etc/
    cd /mnt/mmc
    rm -rf /mnt/mmc/.fw_upgrade
    rm -rf /mnt/mmc/.fw_upgrade.conf


    # Report the status to the caller
    printf "Content-type: text/html\r\n\r\n"
    printf "Upgrade completed, rebooting."

    sync
    sync
    sync
    reboot
fi
