#!/bin/bash

#-------------------------------------------------------------------------------
# fix permissions

for a in keystone libvirt-bin glance rabbitmq-server nova-cert nova-consoleauth nova-api nova-network nova-scheduler nova-vncproxy nova-volume; do sudo service "$a" stop; done
killall -9 dnsmasq

orig_libvirtd_guid=`getent group kvm | cut -d ":" -f3`
new_libvirtd_guid=2001

orig_nova_uid=`id -u nova`
orig_nova_guid=`id -g nova`
new_nova_uid=2000
new_nova_guid=2000

orig_libvirt_dnsmasq_uid=`id -u libvirt-dnsmasq`
new_libvirt_dnsmasq_uid=2002

orig_kvm_guid=`getent group kvm | cut -d ":" -f3`
new_kvm_guid=2003

orig_libvirt_qemu_uid=`id -u libvirt-qemu`
new_libvirt_qemu_uid=2004

# Delete existing/current users & groups
sudo userdel nova
sudo userdel libvirt-qemu
sudo userdel libvirt-dnsmasq
sudo groupdel libvirtd
sudo groupdel kvm

# Fix libvirtd
sudo groupadd -g $new_libvirtd_guid libvirtd
find / -gid $orig_libvirtd_guid -exec chgrp -h $new_libvirtd_guid '{}' \+

# Fix nova
sudo groupadd -g $new_nova_guid nova
sudo useradd -u $new_nova_uid -g $new_nova_guid -d /var/lib/nova -s /bin/false nova
sudo usermod -a -G libvirtd nova
find / -uid $orig_nova_uid -exec chown -h $new_nova_uid '{}' \+
find / -gid $orig_nova_guid -exec chgrp -h $new_nova_guid '{}' \+

# Fix libvirt-dnsmasq
sudo useradd -u $new_libvirt_dnsmasq_uid -g $new_libvirtd_guid -d /var/lib/libvirt/dnsmasq -s /bin/false libvirt-dnsmasq
find / -uid $orig_libvirt_dnsmasq_uid -exec chown -h $new_libvirt_dnsmasq_uid '{}' \+

# Fix kvm
sudo groupadd -g $new_kvm_guid kvm
find / -gid $orig_kvm_guid -exec chgrp -h $new_kvm_guid '{}' \+

# Fix libvirt-qemu
sudo useradd -u $new_libvirt_qemu_uid -g $new_kvm_guid -d /var/lib/libvirt -s /bin/false libvirt-qemu
find / -uid $orig_libvirt_qemu_uid -exec chown -h $new_libvirt_qemu_uid '{}' \+

#-------------------------------------------------------------------------------
# setup nfs

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
