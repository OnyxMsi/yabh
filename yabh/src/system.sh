jls_get_jid() {
    jls -j $1 jid
}
jls_is_running() {
    jls -j $1 > /dev/null 2>&1
}
list_zfs_dataset_children() {
    local dataset=$1
    # Skip first line which is dataset
    for dname in $($ZFS_EXE list -H -d 1 -o name $dataset | tail -n +2) ; do
        basename $dname
    done
}
list_zfs_dataset_snapshots() {
    $ZFS_EXE list -H -o name -t snapshot $1
}
check_kernel_module_loaded() {
    local ret
    kldstat -q -n $1
    ret=$?
    # Strange but these two differs
    if [ $ret -ne 0 ] ; then
        kldstat -q -m $1
        ret=$?
    fi
    return $ret
}
check_kernel_module_loaded_exit() {
    local name=$1
    dbg "Check if kernel module $name is loaded"
    if ! check_kernel_module_loaded $name ; then
        crt $RETURN_ENVIRONMENT_ERROR "Kernel module $name is not loaded"
    fi
}

check_service_enabled() {
    service -e 2> /dev/null | grep --quiet $1
}
get_rc_variable() {
    sysrc -n $1 2> /dev/null
}
check_interface_exists() {
    ifconfig $1 > /dev/null 2>&1
}
check_interface_exists_exit() {
    local ifname=$1
    dbg "Check that interface $ifname exists"
    if ! check_interface_exists $ifname ; then
        crt $RETURN_ENVIRONMENT_ERROR "$ifname: no such network interface"
    fi
}
check_service_enabled_exit() {
    local service=$1
    dbg "Check that $service service is enabled"
    if ! check_service_enabled $service ; then
        crt $RETURN_ENVIRONMENT_ERROR "$service: service is not enabled"
    fi
}
check_sysctl_value() {
    local name=$1
    local value=$2
    test $(sysctl -n $name) = "$value"
}
check_sysctl_value_exit() {
    local name=$1
    local value=$2
    local curvalue=$(sysctl -n $name)
    dbg "Check that kernel $name is $value"
    if ! check_sysctl_value $name $value ; then
        crt $RETURN_ENVIRONMENT_ERROR "Invalid kernel value $name ($curvalue instead of $value)"
    fi
}
check_devfs_ruleset() {
    local name=$1
    if [ -f $DEVFSRULES_PATH ] ; then
        grep -qE "\[$name=[0-9]+\]" $DEVFSRULES_PATH
        return $?
    else
        return 1
    fi
}
check_rc_value() {
    local var_name=$1
    local var_value=$2
    test "$(get_rc_variable $var_name)" = "$var_value"
}
check_rc_value_exit() {
    local var_name=$1
    local var_value=$2
    local curvalue=$(get_rc_variable $var_name)
    dbg "Test that rc.conf $var_name=\"$var_value\""
    if ! check_rc_value $var_name "$var_value" ; then
        crt $RETURN_ENVIRONMENT_ERROR "Invalid $var_name in rc.conf (\"$curvalue\" instead of \"$var_value\")"
    fi
}
zfs_dataset_exists() {
    local name=$1
    $ZFS_EXE list -H -o name | grep --quiet --extended-regexp "\b$name\b"
}
zfs_dataset_snapshot_exists() {
    local dataset_name=$1
    local snapshot_name=$2
    $ZFS_EXE list -H -o name -t snapshot $dataset_name | grep --quiet --extended-regexp "\b$snapshot_name\b"
}
check_zfs_dataset_exists_exit() {
    local name=$1
    dbg "Check that ZFS dataset $name exists"
    if ! zfs_dataset_exists $name ; then
        crt $RETURN_ENVIRONMENT_ERROR "$name: no such ZFS dataset"
    fi
}
create_zfs_dataset_if_not() {
    local name=$1
    if ! zfs_dataset_exists $name ; then
        dbg "Create ZFS dataset $name"
        cmd $ZFS_EXE create -p $name
    fi
}

inet_if_exists() {
    local name=$1
    ifconfig $name > /dev/null 2>&1
}
inet_bridge_has_member() {
    local bridge=$1
    local name=$2
    ifconfig $bridge | grep --quiet --extended-regexp "^\s+member:\s+$name\b"
}

check_system() {
    dbg "Check system configuration"
    check_kernel_module_loaded_exit zfs
    check_service_enabled_exit zfs
    check_zfs_dataset_exists_exit $(configuration_get_dataset_name)
    if [ ! -d $(configuration_get_dataset_mountpoint) ] ; then
        crt $RETURN_ENVIRONMENT_ERROR "$(configuration_get_dataset_mountpoint): no such directory"
    fi
    check_sysctl_value_exit net.inet.ip.forwarding 1
    dbg "System configuration is ready"
}
str_join() {
    local sep=$1 ; shift
    local res
    local el
    while [ $# -gt 0 ] ; do
        el=$1 ; shift
        [ "$res" = "" ] && res=$el || res="$res$sep$el"
    done
    echo $res
}
