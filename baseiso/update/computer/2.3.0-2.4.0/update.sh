#!/bin/bash

set -x

mass_home="/usr/massclouds"
systemd="/lib/systemd/system"
new_iso=$1
previous_iso=$2


if [ -z "${new_iso}" -o -z "${previous_iso}" ]; then
    exit 1
fi

mount_iso() {
    iso=$1
    mkdir /media/cdrom
    if mount | grep -q /media/cdrom; then
        umount /media/cdrom
    fi
    mount ${iso} /media/cdrom
    if [ $? != 0 ]; then
        echo "mount iso failed"
        exit 1
    fi
}

install_debs() {
    echo "deb file:///media/cdrom/ xenial main extras restricted" > /etc/apt/sources.list
    apt-get update
    apt-get dist-upgrade -y --allow-unauthenticated
}

install_old_debs() {
    mount_iso ${previous_iso}
    rm -rf /var/lib/apt/lists/*
    apt-get update
    # reinstall qemu
    dpkg --purge --force-depends qemu-block-extra qemu-kvm qemu-system-x86 qemu-utils qemu-system-common
    apt-get install qemu-block-extra qemu-kvm qemu-system-x86 qemu-utils qemu-system-common -y --allow-unauthenticated
    # reinstall ceph
    cp /etc/ceph/ceph.conf /tmp
    dpkg --purge --force-depends ceph ceph-common libcephfs1 librados2 libradosstriper1 librbd1 librgw2 python-cephfs python-rados python-rbd rbd-mirror btrfs-tools ceph-base ceph-fs-common ceph-fuse ceph-mds ceph-mon ceph-osd liblttng-ust-ctl2 liblttng-ust0 liblzo2-2 liburcu4
    apt-get install ceph ceph-common libcephfs1 librados2 libradosstriper1 librbd1 librgw2 python-rbd python-rados python-cephfs -y --allow-unauthenticated
    cp /tmp/ceph.conf /etc/ceph/
}

replace_code() {
    [ -d ${mass_home}.old ] && rm -rf ${mass_home} && mv ${mass_home}.old ${mass_home}
    mv ${mass_home} ${mass_home}.old
    mkdir ${mass_home}
    tar xf /media/cdrom/jz.tar.gz -C ${mass_home}/
}

copy_cvm_img() {
    mkdir -p ${mass_home}/cvm/backup
    mac=$(grep "mac address" ${mass_home}.old/cvm/cvm.xml)
    cp ${mass_home}/deploy/conf/cvm.xml ${mass_home}/cvm/
    sed -i "/mac address/c\ ${mac}" ${mass_home}/cvm/cvm.xml
    rsync -P /media/cdrom/*.img ${mass_home}/cvm/backup/
    rsync -P /media/cdrom/*.img ${mass_home}/cvm/
    chmod -R 755 ${mass_home}/cvm
}

after_update() {
    cp ${mass_home}/scale/service/ceph-osd@.service ${systemd}/
    cp ${mass_home}/scale/service/ceph-mon@.service ${systemd}/
    cp ${mass_home}/cvm_ha/ceph-mon /usr/bin/
    rm -rf /usr/local/lib/ceph
    cp -r ${mass_home}/cvm_ha/ceph /usr/local/lib/
    systemctl enable ceph-mon@$(hostname).service
    rm -rf ${mass_home}.old
}

after_restore() {
    cp ${mass_home}/scale/service/ceph-osd@.service ${systemd}/
    cp ${mass_home}/cvm_ha/ceph-mon /usr/bin/
    rm -rf /usr/local/lib/ceph
    cp -r ${mass_home}/cvm_ha/ceph /usr/local/lib/
}

update() {
    mount_iso ${new_iso}
    if ! install_debs; then
        install_old_debs
        after_restore
    else
        replace_code
        copy_cvm_img
        after_update
    fi
}

finish() {
    umount /media/cdrom
    echo "" > /etc/apt/sources.list
    rm -rf /var/lib/apt/lists/*
    apt-get update
}

update
finish

