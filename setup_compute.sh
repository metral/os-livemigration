#!/bin/bash

#-------------------------------------------------------------------------------
# fix permissions

for a in libvirt-bin nova-network nova-compute nova-vncproxy ; do sudo service "$a" stop; done
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

# Setup to use existing remote NFS as back-end storage for instances
REMOTE_NFS_IP="10.80.1.46"
REMOTE_NFS_MOUNT="/var/lib/nova/instances"
LOCAL_NFS_MOUNT="/var/lib/nova/instances"

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

# Configure libvirt-bin.conf options
sudo sed -i "s/env libvirtd_opts=\"-d\"/env libvirtd_opts=\"-d -l\"/g" /etc/init/libvirt-bin.conf
sudo sed -i "s/libvirtd_opts=\"-d\"/libvirtd_opts=\"-d -l\"/g" /etc/default/libvirt-bin

# Modify nova.conf to have vncserver not listen on a specific ip
sudo sed -i 's/--vncserver_listen=.*$/#--vncserver_listen=0.0.0.0/g' /etc/nova/nova.conf

# Restart libvirt-bin
sudo /etc/init.d/libvirt-bin stop
sudo /etc/init.d/libvirt-bin start

# Add automount
(cat | sudo tee -a /etc/fstab ) << EOF
$REMOTE_NFS_IP:$REMOTE_NFS_MOUNT 	$LOCAL_NFS_MOUNT    nfs    rw      0        0
EOF
#-------------------------------------------------------------------------------
