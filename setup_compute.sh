#!/bin/bash

#-------------------------------------------------------------------------------
# Fixes the compute node to support live-migration
#-------------------------------------------------------------------------------

# Disable OpenStack & related services
for a in libvirt-bin nova-network nova-compute nova-vncproxy ; \
    do sudo service "$a" stop; done
killall -9 dnsmasq

# Store & set old and new uid & gid's for:
# libvirtd, nova, libvirt-dnsmasq, kvm & libvirt-qemu
orig_libvirtd_gid=`getent group libvirtd | cut -d ":" -f3`
new_libvirtd_gid=2000

orig_nova_uid=`id -u nova`
orig_nova_gid=`id -g nova`
new_nova_uid=2001
new_nova_gid=2001

orig_libvirt_dnsmasq_uid=`id -u libvirt-dnsmasq`
new_libvirt_dnsmasq_uid=2002

orig_kvm_gid=`getent group kvm | cut -d ":" -f3`
new_kvm_gid=2003

orig_libvirt_qemu_uid=`id -u libvirt-qemu`
new_libvirt_qemu_uid=2004

# Delete existing/current users & groups
sudo userdel nova
sudo userdel libvirt-qemu
sudo userdel libvirt-dnsmasq
sudo groupdel libvirtd
sudo groupdel kvm

# Fix libvirtd group & old permissions
sudo groupadd -g $new_libvirtd_gid libvirtd
find / -type d -name proc -prune -o -gid $orig_libvirtd_gid \
    -exec chgrp -h $new_libvirtd_gid '{}' \+

# Fix nova user & group & old permissions
sudo groupadd -g $new_nova_gid nova
sudo useradd -u $new_nova_uid -g $new_nova_gid \
    -d /var/lib/nova -s /bin/false nova
sudo usermod -a -G libvirtd nova
find / -type d -name proc -prune -o -uid $orig_nova_uid \
    -exec chown -h $new_nova_uid '{}' \+
find / -type d -name proc -prune -o -gid $orig_nova_gid \
    -exec chgrp -h $new_nova_gid '{}' \+

# Fix libvirt-dnsmasq user & old permissions
sudo useradd -u $new_libvirt_dnsmasq_uid -g $new_libvirtd_gid \
    -d /var/lib/libvirt/dnsmasq -s /bin/false libvirt-dnsmasq
find / -type d -name proc -prune -o -uid $orig_libvirt_dnsmasq_uid \
    -exec chown -h $new_libvirt_dnsmasq_uid '{}' \+

# Fix kvm & old permissions
sudo groupadd -g $new_kvm_gid kvm
find / -type d -name proc -prune -o -gid $orig_kvm_gid \
    -exec chgrp -h $new_kvm_gid '{}' \+

# Fix libvirt-qemu & old permissions
sudo useradd -u $new_libvirt_qemu_uid -g $new_kvm_gid \
    -d /var/lib/libvirt -s /bin/false libvirt-qemu
find / -type d -name proc -prune -o -uid $orig_libvirt_qemu_uid \
    -exec chown -h $new_libvirt_qemu_uid '{}' \+

#-------------------------------------------------------------------------------

# Remote (on the controller) NFS server settings
REMOTE_NFS_IP=$1
REMOTE_NFS_MOUNT="/var/lib/nova/instances"
LOCAL_NFS_MOUNT="/var/lib/nova/instances"

# Install & mount NFS server
sudo apt-get update; sudo apt-get install nfs-common -y
sudo mount $REMOTE_NFS_IP:$REMOTE_NFS_MOUNT $LOCAL_NFS_MOUNT
sudo chown -R nova:nova /var/lib/nova/instances

# Configure libvirtd.conf options
UUID=`cat /sys/class/dmi/id/product_uuid`
(cat | sudo tee -a /etc/libvirt/libvirtd.conf ) << EOF
host_uuid = '$UUID'
listen_tls = 0
listen_tcp = 1
auth_tcp = 'none'
EOF

# Configure libvirt-bin.conf & libvirt-bin options
sudo sed -i "s/env libvirtd_opts=\"-d\"/env libvirtd_opts=\"-d -l\"/g" \
    /etc/init/libvirt-bin.conf
sudo sed -i "s/libvirtd_opts=\"-d\"/libvirtd_opts=\"-d -l\"/g" \
    /etc/default/libvirt-bin

# Modify nova.conf to not listen on a specific local vncserver
sudo sed -i 's/--vncserver_listen=.*$/#--vncserver_listen=0.0.0.0/g' \
    /etc/nova/nova.conf

# Restart libvirt-bin
sudo /etc/init.d/libvirt-bin stop
sudo /etc/init.d/libvirt-bin start

# Mount NFS server on boot
(cat | sudo tee -a /etc/fstab ) << EOF
$REMOTE_NFS_IP:$REMOTE_NFS_MOUNT $LOCAL_NFS_MOUNT   nfs   defaults    0     0
EOF
#-------------------------------------------------------------------------------
