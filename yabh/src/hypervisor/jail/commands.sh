jail_crt() {
    crt $RETURN_JAIL_ERROR $*
}
check_release_exists_exit() {
    local name=$1
    dbg "Check that release $name exists"
    if ! hypervisor_release_exists $name ; then
        jail_crt "$name: no such release"
    fi
}
check_jail_exists_exit() {
    name=$1
    if ! hypervisor_jail_exists $name ; then
        jail_crt "$name: no such jail"
    fi
}
check_jail_config_exit() {
    local name=$1
    local config=$(hypervisor_jail_get_config_path $name)
    if ! hypervisor_jail_check_configuration $name $config ; then
        jail_crt "$name: Invalid configuration"
    fi
}
jail_release_add() {
    local release_name=$1
    crt_not_enough_argument 1 $*
    dbg "Get release $release_name"
    if hypervisor_release_exists $release_name ; then
        if force_is_set ; then
            wrn "Release $release_name is set, remove it"
            jail_release_remove $release_name
        else
            jail_crt "Release $release_name already exists"
        fi
    fi
    # If this is the current host release, fetch it properly
    if hypervisor_release_is_host_release $release_name ; then
        if ! hypervisor_release_fetch_host_release ; then
            jail_crt "Can't fetch $release_name"
        fi
    else
        if ! hypervisor_release_fetch $release_name ; then
            jail_crt "Can't fetch $release_name"
        fi
    fi
    inf "Release $release_name was added"
}
jail_release_list() {
    hypervisor_release_list
}
jail_release_remove() {
    local release_name=$1
    crt_not_enough_argument 1 $*
    check_release_exists_exit $release_name
    # Make sure there is no running jail with this release
    for jail_name in $(hypervisor_jail_list) ; do
        check_jail_config_exit $jail_name
        jail_release=$(hypervisor_jail_config_get_release $jail_config)
        if [ "$jail_release" = "$release_name" ] && jls_is_running $jail_name ; then
            if force_is_set ; then
                wrn "Jail $jail_name is using release $release_name, stop it"
                jail_stop $jail_name
            else
                jail_crt "Release $release_name is used by $jail_name which is still running"
            fi
        fi
    done
    if ! hypervisor_release_remove $release_name ; then
        jail_crt "Can't remove release $release_name"
    fi
    inf "Release $release_name was deleted"
}
jail_add() {
    local jail_name=$1
    local release_name=$2
    crt_not_enough_argument 2 $*
    check_release_exists_exit $release_name
    if hypervisor_jail_exists $jail_name ; then
        if force_is_set ; then
            wrn "Jail $jail_name already exists, remove it"
            jail_remove $jail_name
        else
            jail_crt "Jail $jail_name already exists"
        fi
    fi
    if ! hypervisor_jail_create $jail_name $release_name; then
        jail_crt "Can't create jail $jail_name"
    fi
    inf "Jail $jail_name was created"
}
jail_list() {
    local fields=${1:-$DEFAULT_JAIL_LIST_FIELDS}
    local jail_name
    local jail_conf
    local fields
    local line
    for jail_name in $(hypervisor_jail_list) ; do
        check_jail_exists_exit $jail_name
        jail_conf=$(hypervisor_jail_get_config_path $jail_name)
        line=""
        for field in $(echo $fields) ; do
            value=$(hypervisor_jail_config_get_parameter $jail_conf $field)
            [ "$line" = "" ] && line=$value || line="${line}${LIST_SEPARATOR}${value}"
        done
        echo $line
    done
}
check_jail_is_stopped_exit_or_stop() {
    local name=$1
    if jls_is_running $name ; then
        if force_is_set ; then
            wrn "Jail $name is running, stop it"
            jail_stop $name
        else
            jail_crt "Jail $name is running"
        fi
    fi
}
jail_remove() {
    crt_not_enough_argument 1 $*
    local jail_name=$1
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    hypervisor_jail_remove $jail_name
    inf "Jail $jail_name was removed"
}
jail_list_with_priority() {
    local jail
    local jail_config
    local priority
    local priority_list=""
    local flags
    [ $# -eq 0 ] && jails=$(hypervisor_jail_list) || jails="$*"
    for jail in $(echo $jails) ; do
        jail_config=$(hypervisor_jail_get_config_path $jail)
        priority=$(hypervisor_jail_config_get_parameter $jail_config priority)
        echo "$priority $jail"
    done
}
jail_list_sort_by_priority() {
    jail_list_with_priority $* | sort -g | cut -f 2 -d " "
}
jail_list_sort_by_priority_reversed() {
    jail_list_with_priority $* | sort -rg | cut -f 2 -d " "
}
jail_start() {
    for jail_name in $(jail_list_sort_by_priority $*) ; do
        check_jail_exists_exit $jail_name
        check_jail_config_exit $jail_name
        check_jail_is_stopped_exit_or_stop $jail_name
        if jls_is_running $jail_name ; then
            jail_crt "$jail_name is already running"
        else
            if ! hypervisor_jail_start $jail_name ; then
                jail_crt "Can't start $jail_name"
            fi
            inf "Jail $jail_name was started"
        fi
    done
}
jail_stop() {
    for jail_name in $(jail_list_sort_by_priority_reversed $*) ; do
        check_jail_exists_exit $jail_name
        check_jail_config_exit $jail_name
        if ! jls_is_running $jail_name ; then
            wrn "Jail $jail_name is not running"
        else
            hypervisor_jail_stop $jail_name
            inf "Jail $jail_name was stopped"
        fi
    done
}
jail_restart() {
    crt_not_enough_argument 1 $*
    jail_stop $*
    jail_start $*
}
jail_set() {
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    local parameter_name=$2
    local parameter_value=$3
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if [ "$parameter_value" = "" ] ; then
        hypervisor_jail_config_remove_parameter $jail_config $parameter_name
        inf "Jail $jail_name parameter $parameter_name was unset"
    else
        hypervisor_jail_config_set_parameter $jail_config $parameter_name "$parameter_value"
        inf "Jail $jail_name parameter $parameter_name -> $parameter_value"
    fi
    if ! hypervisor_jail_create_ucl_configuration_file $jail_name ; then
        jail_crt "Can't create UCL configuration file for $jail_name"
    fi
}
jail_get() {
    crt_not_enough_argument 2 $*
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    local parameter_name=$2
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    hypervisor_jail_config_get_parameter $jail_config $parameter_name
}
jail_dataset_add() {
    local jail_name=$1
    local dataset=$2
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    crt_not_enough_argument 2 $*
    if ! zfs_dataset_exists $dataset ; then
        crt $RETURN_COMMANDLINE_ERROR "$dataset: no such ZFS dataset"
    fi
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if hypervisor_jail_config_has_dataset $jail_config $dataset ; then
        wrn "Dataset $dataset is already set in $jail_name"
    elif ! hypervisor_jail_config_add_dataset $jail_config $dataset ; then
        jail_crt "Can't add dataset $dataset to jail $jail_name"
    fi
    if ! hypervisor_jail_create_ucl_configuration_file $jail_name ; then
        jail_crt "Can't create UCL configuration file for $jail_name"
    fi
    inf "Dataset $dataset was added to jail $jail_name"
}
jail_dataset_list() {
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    hypervisor_jail_config_list_datasets $jail_config
}
jail_dataset_remove() {
    local jail_name=$1
    local dataset=$2
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    crt_not_enough_argument 2 $*
    if ! zfs_dataset_exists $dataset ; then
        crt $RETURN_COMMANDLINE_ERROR "$dataset: no such ZFS dataset"
    fi
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if hypervisor_jail_config_has_dataset $jail_config $dataset ; then
        if ! hypervisor_jail_config_remove_dataset $jail_config $dataset ; then
            jail_crt "Can't remove dataset $dataset from jail $jail_name"
        fi
    else
        crt $RETURN_COMMANDLINE_ERROR "Dataset $dataset is not set for jail $jail_name"
    fi
    if ! hypervisor_jail_create_ucl_configuration_file $jail_name ; then
        jail_crt "Can't create UCL configuration file for $jail_name"
    fi
}
jail_export() {
    local jail_name=$1
    local src=$2
    local dest=$3
    local jail_root=$(hypervisor_jail_get_root_path $jail_name)
    local dest_dir
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    if [ ! -f $src ] ; then
        jail_crt $RETURN_COMMANDLINE_ERROR "$src: no such file"
    fi
    final_src=$(realpath $src)
    if [ "$dest" = "" ] ; then
        dbg "Destination path is not set, use source $src"
        final_dest="$jail_root$src"
    else
        final_dest="$jail_root$dest"
    fi
    dbg "Copy $final_src into $final_dest"
    cmd cp $final_src $final_dest
}
check_snapshot_exit() {
    local dataset=$1
    local snapshot=$1
    if ! zfs_dataset_snapshot_exists $dataset $snapshot ; then
        jail_crt $RETURN_COMMANDLINE_ERROR "$snapshot: no such snapshot for dataset $dataset"
    fi
}
jail_snapshot_add() {
    local jail_name=$1
    local jail_dataset=$(hypervisor_jail_get_dataset_name $jail_name)
    local default_snapname="$jail_dataset@$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    local snapname=$2
    crt_not_enough_argument 1 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    dbg "Take dataset $jail_dataset snapshot of jail $jail_name"
    cmd $ZFS_EXE snapshot $default_snapname
    if [ "$snapname" != "" ] ; then
        full_snapname="$jail_dataset@$snapname"
        if zfs_dataset_snapshot_exists $jail_dataset $full_snapname ; then
            dbg "Dataset $jail_dataset snapshot $full_snapname already exists, remove it"
            cmd $ZFS_EXE destroy $full_snapname
        fi
        dbg "Rename $default_snapname into $full_snapname"
        cmd $ZFS_EXE rename $default_snapname $snapname
    fi
    inf "New snapshot was created for jail $jail_name"
}
jail_snapshot_list() {
    local jail_name=$1
    local jail_dataset=$(hypervisor_jail_get_dataset_name $jail_name)
    crt_not_enough_argument 1 $*
    check_jail_exists_exit $jail_name
    list_zfs_dataset_snapshots $jail_dataset
}
jail_snapshot_remove() {
    local jail_name=$1
    local snapname=$2
    local jail_dataset=$(hypervisor_jail_get_dataset_name $jail_name)
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_snapshot_exit $jail_dataset $snapname
    dbg "Remove dataset $jail_dataset snapshot $snapname"
    cmd $ZFS_EXE destroy $snapname
    inf "Snapshot $snapname from jail $jail_name was deleted"
}
jail_snapshot_restore() {
    local jail_name=$1
    local snapname=$2
    local jail_dataset=$(hypervisor_jail_get_dataset_name $jail_name)
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    check_snapshot_exit $jail_dataset $snapname
    dbg "Restore dataset $jail_dataset into snapshot $snapname"
    cmd $ZFS_EXE rollback $snapname
    inf "Jail $jail_name was restored to snapsnot $snapname"
}
jail_interface_add() {
    local jail_name=$1
    local bridge_name=$2
    local interface_name=$3
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if [ "$interface_name" = "" ] ; then
        dbg "Generate interface name for $jail_name"
        interface_name=$(hypervisor_jail_interface_get_next_name $jail_name)
    fi
    if ! hypervisor_jail_interface_add $jail_name $bridge_name $interface_name ; then
        jail_crt "Can't add interface $Interface_name to $jail_name"
    fi
    if ! hypervisor_jail_create_ucl_configuration_file $jail_name ; then
        jail_crt "Can't create UCL configuration file for $jail_name"
    fi
    inf "Interface $interface_name was added to $jail_name"
}
jail_interface_remove() {
    local jail_name=$1
    local interface_name=$2
    crt_not_enough_argument 2 $*
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if ! hypervisor_jail_interface_remove $jail_name $interface_name ; then
        jail_crt "Can't remove interface $interface_name from $jail_name"
    fi
    if ! hypervisor_jail_create_ucl_configuration_file $jail_name ; then
        jail_crt "Can't create UCL configuration file for $jail_name"
    fi
    inf "Interface $interface_name was removed from $jail_name"
}
jail_interface_list() {
    local jail_name=$1
    local bridge_name
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    crt_not_enough_argument 1 $*
    check_jail_exists_exit $jail_name
    for if_name in $(hypervisor_jail_config_list_interfaces $jail_config) ; do
        echo "$if_name,$(hypervisor_jail_config_interface_get_bridge_name $jail_config $if_name)"
    done
}
