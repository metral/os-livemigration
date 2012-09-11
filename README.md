<!---------------------------------------------------------------------------->

# Enable live-migration on OpenStack

<!---------------------------------------------------------------------------->

<h3>Description</h3>
These scripts will configure shared UID & GID's and permissions across all 
cluster nodes for the services libvirt, nova, kvm, libvirt-qemu & 
libvirt-dnsmasq to allow for the usage of instances off of a shared 
NFS server back-end.

These scripts assume:

- A vanilla OpenStack installation with nodes assumming either a controller or
compute role.
    -  I'm currently using OpenStack Essex 2012.1.3-dev
- That all nodes, controllers & computes, have DNS or /etc/hosts configured to 
know of the rest of the nodes in the cluster via hostname since 
live-migration requires it.

Alternations performed:

    - Controller:
        - Installs libvirt-bin & kvm
        - Alters the proper linux UID & GID's
        - Sets up an NFS Server
    - Compute:
        - Alters the proper linux UID & GID's
        - Updates the libvirt configurations
        - Sets up an NFS client to the NFS server on the controller node

<!---------------------------------------------------------------------------->

<h3>Installation/Modifications</h3>
- Controller:
    - `./setup_controller.sh`
    - `reboot`
- Compute
    - `./setup_compute.sh <CONTROLLER_IP>`
        - i.e. `./setup_compute.sh 10.1.1.1`
    - `reboot`

<!---------------------------------------------------------------------------->

<h3>Using Live-Migration</h3>
1. Boot up a VM in nova from the controller:
    - `nova boot --flavor=<FLAVOR> --image=<IMAGE> <VM_NAME>`
2. Show VM details:
    - `nova show <VM_NAME>`
    - This VM should be on one of the compute node hosts
3. Verify that the hosts are using & can see the instance on the shared NFS server
    - `ls -alh /var/lib/nova/instances/<INSTANCE_NAME>`
4. Once the VM is up, perform the live-migration from the controller
    - `nova live-migration <VM_NAME> <OTHER_COMPUTE_HOSTNAME>`
    - Remember, all nodes should have DNS & /etc/hosts configured to know of
      the rest of the nodes via hostname for this to work
5. View migration status from controller:
    - `nova list`
6. Once the migration is done & the VM is active, verify VM is in fact no 
longer running on original compute node & instead it
is on the new node by viewing the qemu process details on both compute nodes:
    - `ps aux | grep qemu`
    - The qemu process should only be on the new compute node

<!---------------------------------------------------------------------------->
