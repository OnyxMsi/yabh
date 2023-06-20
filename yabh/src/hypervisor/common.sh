hypervisor_get_dataset_root_name() {
    configuration_get_dataset_name
}
hypervisor_get_dataset_iso_name() {
    echo "$(hypervisor_get_dataset_root_name)/isos"
}
hypervisor_get_dataset_release_name() {
    echo "$(hypervisor_get_dataset_root_name)/releases"
}
hypervisor_get_dataset_jail_name() {
    echo "$(hypervisor_get_dataset_root_name)/jails"
}
hypervisor_get_dataset_vm_name() {
    echo "$(hypervisor_get_dataset_root_name)/vms"
}
hypervisor_get_dataset_root_mountpoint() {
    configuration_get_dataset_mountpoint
}
hypervisor_get_dataset_iso_mountpoint() {
    echo "$(hypervisor_get_dataset_root_mountpoint)/isos"
}
hypervisor_get_dataset_release_mountpoint() {
    echo "$(hypervisor_get_dataset_root_mountpoint)/releases"
}
hypervisor_get_dataset_jail_mountpoint() {
    echo "$(hypervisor_get_dataset_root_mountpoint)/jails"
}
hypervisor_get_dataset_vm_mountpoint() {
    echo "$(hypervisor_get_dataset_root_mountpoint)/vms"
}

check_hypervisor() {
    dbg "Check hypervisor configuration"
    # Dataset
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_root_name)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_iso_name)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_release_name)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_jail_name)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_vm_name)
    # Jail
    # Virtual machine
    check_kernel_module_loaded_exit vmm
    check_kernel_module_loaded_exit nmdm
    check_kernel_module_loaded_exit if_tap
    dbg "hypervisor configuration is ready"
}
init_hypervisor() {
    dbg "Initialize hypervisor configuration"
    # Dataset
    create_zfs_dataset_if_not $(hypervisor_get_dataset_root_name)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_iso_name)
    cmd $ZFS_EXE set exec=off $(hypervisor_get_dataset_iso_name)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_release_name)
    cmd $ZFS_EXE set exec=off $(hypervisor_get_dataset_release_name)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_jail_name)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_vm_name)
    cmd $ZFS_EXE set exec=off $(hypervisor_get_dataset_vm_name)
    # Jail
    # Virtual machine
    dbg "Hypervisor configuration initialized"
}
hv_dbg() {
    dbg "[hypervisor] $*"
}
hv_inf() {
    inf "[hypervisor] $*"
}
hv_err() {
    err "[hypervisor] $*"
}
hv_wrn() {
    wrn "[hypervisor] $*"
}
