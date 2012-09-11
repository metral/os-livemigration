#!/bin/bash

#-------------------------------------------------------------------------------
# Fixes the controller node to support live-migration
#-------------------------------------------------------------------------------

# Disable OpenStack & related services
for a in keystone libvirt-bin glance rabbitmq-server nova-cert \
    nova-consoleauth nova-api nova-network nova-scheduler nova-vncproxy \
    nova-volume; do sudo service "$a" stop; done
killall -9 dnsmasq

# Install libvirt-bin & kvm on the controller (in case they're not installed)
sudo apt-get update ; sudo apt-get install libvirt-bin kvm -y

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

# Set local NFS server mount point
NFS_MOUNT=/var/lib/nova/instances

# Install NFS server
sudo apt-get update; sudo apt-get install nfs-kernel-server -y

# Configure NFS
sudo mkdir -p $NFS_MOUNT
sudo chmod -R 777 $NFS_MOUNT
(cat | sudo tee -a /etc/exports) << EOF
$NFS_MOUNT 	*(rw,sync,no_root_squash)
EOF

# Start NFS server
sudo /etc/init.d/nfs-kernel-server start
#-------------------------------------------------------------------------------
