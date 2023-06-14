hypervisor_get_dataset_root_name() {
    configuration_get_dataset_name
}
hypervisor_get_dataset_iso_name() {
    echo "$(hypervisor_get_dataset_root_name)/isos"
}
hypervisor_get_dataset_release_name() {
    echo "$(hypervisor_get_dataset_root_name)/releases"
}
hypervisor_get_dataset_snapshot_name() {
    echo "$(hypervisor_get_dataset_root_name)/snapshots"
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
hypervisor_get_dataset_snapshot_mountpoint() {
    echo "$(hypervisor_get_dataset_root_mountpoint)/snapshots"
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
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_snapshot_name)
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
    create_zfs_dataset_if_not $(hypervisor_get_dataset_snapshot_name)
    cmd $ZFS_EXE set exec=off $(hypervisor_get_dataset_snapshot_name)
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

#
# Jail
#
hypervisor_release_get_dataset_name() {
    echo "$(hypervisor_get_dataset_release_name)/$1"
}
hypervisor_release_get_dataset_mountpoint() {
    echo "$(hypervisor_get_dataset_release_mountpoint)/$1"
}
hypervisor_release_get_root_path() {
    echo "$(hypervisor_release_get_dataset_mountpoint $1)/root"
}
hypervisor_release_exists() {
    zfs_dataset_exists $(hypervisor_release_get_dataset_name $1)
}
hypervisor_release_fetch() {
    local name=$1
    local release_url="$HYPERVISOR_RELEASE_BASE_URL/$name"
    local release_dataset=$(hypervisor_release_get_dataset_name $name)
    local release_root
    local release_fetch
    hv_dbg "[$name] Fetch release"
    if hypervisor_release_exists $name ; then
        hv_err "[$name] Release already exists"
        return 1
    fi
    hv_dbg "[$name] Create zfs dataset $release_dataset"
    cmd $ZFS_EXE create -p $release_dataset
    cmd $ZFS_EXE set exec=off $release_dataset
    release_root=$(hypervisor_release_get_root_path $name)
    release_fetch="$(hypervisor_release_get_dataset_mountpoint $name)/fetch"
    hv_dbg "[$name] Create release root $release_root"
    mkdir -p $release_root
    hv_dbg "[$name] Create release fetch $release_fetch"
    mkdir -p $release_fetch
    # Now use bsdinstall to fetch release
    export DISTRIBUTIONS="base.txz"
    export BSDINSTALL_DISTSITE=$release_url
    export BSDINSTALL_DISTDIR=$release_fetch
    export BSDINSTALL_CHROOT=$release_root
    export noninteractive="YES"
    cmd bsdinstall distfetch
    cmd bsdinstall distextract
    hv_dbg "[$name] Remove release $name fetch directory $release_fetch"
    rm -rf $release_fetch
    hv_dbg "[$name] Make zfs dataset readonly"
    cmd $ZFS_EXE set readonly=on $release_dataset
    hv_inf "[$name] Release $name fetched"
}
hypervisor_release_remove() {
    local name=$1
    local release_dataset=$(hypervisor_release_get_dataset_name $name)
    if ! hypervisor_release_exists $name ; then
        hv_err "[$name] no such release"
    fi
    hv_dbg "[$name] Remove release $release_dataset"
    cmd $ZFS_EXE destroy -Rf $release_dataset
    hv_inf "[$name] Release was removed"
}
hypervisor_release_list() {
    list_zfs_dataset_children $(hypervisor_get_dataset_release_name)
}
# Jail
hypervisor_jail_get_dataset_name() {
    echo "$(hypervisor_get_dataset_jail_name)/$1"
}
hypervisor_jail_get_dataset_mountpoint() {
    echo "$(hypervisor_get_dataset_jail_mountpoint)/$1"
}
hypervisor_jail_get_root_path() {
    echo "$(hypervisor_jail_get_dataset_mountpoint $1)/root"
}
hypervisor_jail_get_config_path() {
    echo "$(hypervisor_jail_get_dataset_mountpoint $1)/config.json"
}
hypervisor_jail_get_ucl_config_path() {
    echo "$(hypervisor_jail_get_dataset_mountpoint $1)/jail.conf"
}
hypervisor_jail_get_fstab_path() {
    echo "$(hypervisor_jail_get_dataset_mountpoint $1)/fstab"
}
hypervisor_jail_get_vnet_if_name() {
    local name=$1
    echo "epair_$name"
}
hypervisor_jail_exists() {
    zfs_dataset_exists $(hypervisor_jail_get_dataset_name $1)
}
hypervisor_jail_list() {
    list_zfs_dataset_children $(hypervisor_get_dataset_jail_name)
}
hypervisor_jail_create() {
    local name=$1
    local release=$2
    hv_dbg "[$name] Create jail on release $release"
    if hypervisor_jail_exists $name ; then
        hv_err "[$name] Jail already exists"
        return 1
    fi
    if ! hypervisor_release_exists $release ; then
        hv_err "[$name] Can't create jail: release $release does not exists"
        return 1
    fi
    local jail_dataset=$(hypervisor_jail_get_dataset_name $name)
    local release_root=$(hypervisor_release_get_root_path $release)
    hv_dbg "[$name] Create jail dataset $jail_dataset"
    cmd $ZFS_EXE create -p $jail_dataset
    jail_root=$(hypervisor_jail_get_root_path $name)
    hv_dbg "[$name] Create jail skeleton at $jail_root"
    mkdir -p $jail_root
    mkdir -p "$jail_root/dev"
    mkdir -p "$jail_root/tmp"
    mkdir -p "$jail_root/usr/local/bin"
    mkdir -p "$jail_root/usr/local/etc"
    mkdir -p "$jail_root/usr/local/include"
    mkdir -p "$jail_root/usr/local/lib"
    mkdir -p "$jail_root/usr/local/libdata"
    mkdir -p "$jail_root/usr/local/libexec"
    mkdir -p "$jail_root/usr/local/man"
    mkdir -p "$jail_root/usr/local/sbin"
    mkdir -p "$jail_root/usr/local/share"
    cp -aR "$release_root/etc" "$jail_root/etc"
    cp -aR "$release_root/var" "$jail_root/var"
    # These are mountpoints
    mkdir -p $jail_root/bin
    mkdir -p $jail_root/boot
    mkdir -p $jail_root/lib
    mkdir -p $jail_root/libexec
    mkdir -p $jail_root/rescue
    mkdir -p $jail_root/sbin
    mkdir -p $jail_root/usr/bin
    mkdir -p $jail_root/usr/include
    mkdir -p $jail_root/usr/lib
    mkdir -p $jail_root/usr/libexec
    mkdir -p $jail_root/usr/sbin
    mkdir -p $jail_root/usr/share
    mkdir -p $jail_root/usr/libdata
    mkdir -p $jail_root/usr/lib32
    hv_dbg "[$name] Create jail /etc/rc.conf"
    cat > "$jail_root/etc/rc.conf" << EOF
hostname="$name"
cron_flags="\$cron_flags -J 15"
# Disable sendmail
sendmail_enable="NO"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
# Clean tmp
clear_tmp_enable="YES"
# Run secure syslog
syslogd_flags="-c -ss"
# Enable IPv6
ipv6_activate_all_interfaces="YES"
EOF
    jail_config=$(hypervisor_jail_get_config_path $name)
    hv_dbg "[$name] Create jail configuration file $jail_config"
    cat > $jail_config << EOF
{
    "datasets": [
    ],
    "yabh_parameters": {
        "priority": 0,
        "release": "$release"
    },
    "jail_parameters": {
        "host.hostname": "$name",
        "path": "$jail_root",
        "persist": true,
        "vnet": true,
        "mount.devfs": true,
        "devfs_ruleset": "$JAIL_DEFAULT_DEVFSRULESET",
        "exec.start": "/bin/sh /etc/rc",
        "exec.stop": "/bin/sh /etc/rc.shutdown"
    }
}
EOF
    hv_inf "[$name] Jail was created"
    return 0
}
hypervisor_jail_check_configuration() {
    local jail_name=$1
    local conf_path=$2
    local conf=
    local release=
    hv_dbg "[$jail_name] Check jail configuration file $conf_path"
    if [ ! -f $conf_path ] ; then
        hv_err "[$jail_name] $conf_path: no such configuration file"
        return 1
    fi
    if ! jq_has_key "$conf_path" . yabh_parameters ; then
        hv_err "[$jail_name] No yabh_parameters in configuration"
        return 1
    fi
    if ! jq_has_key "$conf_path" .yabh_parameters release ; then
        hv_err "[$jail_name] No .yabh_parameters.release in configuration"
        return 1
    fi
    if ! jq_has_key "$conf_path" .yabh_parameters priority ; then
        hv_err "[$jail_name] No .yabh_parameters.priority in configuration"
        return 1
    fi
    release=$(hypervisor_jail_config_get_release $conf_path)
    if ! hypervisor_release_exists $release ; then
        hv_err "[$jail_name] Unknown release $release"
        return 1
    fi
    if ! jq_has_key "$conf_path" . jail_parameters ; then
        hv_err "[$jail_name] No parameters in configuration"
        return 1
    fi
    if ! jq_has_key "$conf_path" . datasets ; then
        hv_err "[$jail_name] No datasets in configuration"
        return 1
    fi
    hv_dbg "[$jail_name] Configuration file is OK"
}
hypervisor_jail_config_get_release() {
    jq_get $1 .yabh_parameters.release
}
hypervisor_jail_config_is_yabh_parameter() {
    local conf_path=$1
    local parameter_name=$2
    # Works only becausse every yabh parameter has a default value
    test $(jq_get $conf_path ".yabh_parameters | has(\"$parameter_name\")") = true
}
hypervisor_jail_config_get_parameter_parent_path() {
    local conf_path=$1
    local parameter_name=$2
    if hypervisor_jail_config_is_yabh_parameter $conf_path $parameter_name ; then
        echo ".yabh_parameters"
    else
        echo ".jail_parameters"
    fi
}
hypervisor_jail_config_set_parameter() {
    local conf_path=$1
    local parameter_name=$2
    local parameter_value=$3
    local param_path=$(hypervisor_jail_config_get_parameter_parent_path $conf_path $parameter_name)
    jq_edit $conf_path "$param_path[\"$parameter_name\"] = \"$parameter_value\""
}
hypervisor_jail_config_get_parameter() {
    local conf_path=$1
    local parameter_name=$2
    local param_path=$(hypervisor_jail_config_get_parameter_parent_path $conf_path $parameter_name)
    jq_get $conf_path "$param_path[\"$parameter_name\"]"
}
hypervisor_jail_config_has_parameter() {
    local conf_path=$1
    local parameter_name=$2
    local param_path=$(hypervisor_jail_config_get_parameter_parent_path $conf_path $parameter_name)
    test $(jq_get $conf_path "$param_path | has(\"$parameter_name\")") = true
}
hypervisor_jail_config_has_parameter_with_value() {
    local conf_path=$1
    local parameter_name=$2
    local parameter_value=$3
    hypervisor_jail_config_has_parameter $conf_path $parameter_name && test "$(hypervisor_jail_config_get_parameter $conf_path $parameter_name)" = "$parameter_value"

}
hypervisor_jail_config_remove_parameter() {
    local conf_path=$1
    local parameter_name=$2
    local param_path=$(hypervisor_jail_config_get_parameter_parent_path $conf_path $parameter_name)
    jq_edit $conf_path "del($param_path[\"$parameter_name\"])"
}
hypervisor_jail_config_list_jail_parameters() {
    jq_get $1 ".jail_parameters | keys | .[]"
}
hypervisor_jail_config_add_dataset() {
    local conf_path=$1
    local dataset=$2
    if ! hypervisor_jail_config_has_dataset $conf_path $dataset ; then
        jq_edit $conf_path ".datasets += [\"$dataset\"]"
    fi
    # If already there do nothing
}
hypervisor_jail_config_has_dataset() {
    local conf_path=$1
    local dataset=$2
    test $(jq_get $conf_path ".datasets | index(\"$dataset\")") != "null"
}
hypervisor_jail_config_has_datasets() {
    jq_is_empty $1 ".datasets" && return 1 || return 0
}
hypervisor_jail_config_remove_dataset() {
    local conf_path=$1
    local dataset=$2
    if hypervisor_jail_config_has_dataset $conf_path $dataset ; then
        jq_edit $conf_path ".datasets | del(.[index(\"$dataset\")])"
    fi
}
hypervisor_jail_config_list_datasets() {
    local conf_path=$1
    jq_get $1 ".datasets | .[]"
}
hypervisor_append_to_ucl_file() {
    local path=$1
    local name=$2
    local value=$3
    local s=
    if [ "$value" = "" ] ; then
        s="$name;"
    else
        s="$name = \"$value\";"
    fi
    echo "    $s" >> $path
}
hypervisor_jail_start() {
    local name=$1
    local jail_config=$(hypervisor_jail_get_config_path $name)
    local jail_fstab=$(hypervisor_jail_get_fstab_path $name)
    local jail_root=$(hypervisor_jail_get_root_path $name)
    local jail_ucl_conf_path=$(hypervisor_jail_get_ucl_config_path $name)
    local bridge_name=$(configuration_get_bridge_interface)
    local jail_inet_name
    local jail_release
    local release_root
    hv_dbg "[$name] Generate jail data before start"
    if jls_is_running $name ; then
        hv_err "There is already a jail $name running"
        return 1
    fi
    if [ ! -f $jail_config ] ; then
        hv_err "[$name] $jail_config: no such configuration file"
        return 1
    fi
    if [ ! -d $jail_root ] ; then
        hv_err "[$name] $jail_root: no such root directory"
        return 1
    fi
    if ! hypervisor_jail_check_configuration $name $jail_config ; then
        hv_err "[$name] Invalid configuration"
        return 1
    fi
    # This just helpful
    if hypervisor_jail_config_has_datasets $jail_config ; then
        hv_dbg "[$name] ZFS datasets are expected, check configuration"
        if ! hypervisor_jail_config_has_parameter_with_value $jail_config allow.mount true ; then
            hv_err "[$name] Parameter allow.mount must be set to true in order to use ZFS datasets"
            return 1
        fi
        if ! hypervisor_jail_config_has_parameter_with_value $jail_config allow.mount.zfs true ; then
            hv_err "[$name] Parameter allow.mount.zfs must be set to true in order to use ZFS datasets"
            return 1
        fi
        if ! hypervisor_jail_config_has_parameter $jail_config enforce_statfs || [ "$(hypervisor_jail_config_get_parameter $jail_config enforce_statfs)" -ge 2 ] ; then
            hv_err "[$name] Parameter enforce_statfs must be set lower than 2 in order to use ZFS datasets"
        fi
    fi
    if [ -f $jail_ucl_conf_path ] ; then
        hv_wrn "[$name] UCL configuration file $jail_ucl_conf_path exists, that means jail was not stopped properly"
    fi
    if [ -f $jail_fstab ] ; then
        hv_wrn "[$name] fstab file $jail_fstab exists, that means jail was not stopped properly"
    fi
    jail_release=$(hypervisor_jail_config_get_release $jail_config)
    release_root=$(hypervisor_release_get_root_path $jail_release)
    hv_dbg "[$name] Generate fstab $jail_fstab"
    cat > $jail_fstab << EOF
$release_root/bin $jail_root/bin nullfs ro 0 0
$release_root/boot $jail_root/boot nullfs ro 0 0
$release_root/lib $jail_root/lib nullfs ro 0 0
$release_root/libexec $jail_root/libexec nullfs ro 0 0
$release_root/rescue $jail_root/rescue nullfs ro 0 0
$release_root/sbin $jail_root/sbin nullfs ro 0 0
$release_root/usr/bin $jail_root/usr/bin nullfs ro 0 0
$release_root/usr/include $jail_root/usr/include nullfs ro 0 0
$release_root/usr/lib $jail_root/usr/lib nullfs ro 0 0
$release_root/usr/libexec $jail_root/usr/libexec nullfs ro 0 0
$release_root/usr/sbin $jail_root/usr/sbin nullfs ro 0 0
$release_root/usr/share $jail_root/usr/share nullfs ro 0 0
$release_root/usr/libdata $jail_root/usr/libdata nullfs ro 0 0
$release_root/usr/lib32 $jail_root/usr/lib32 nullfs ro 0 0
EOF
    hv_dbg "[$name] Create interface"
    jail_inet_a=$(ifconfig epair create)
    jail_inet_b="${jail_inet_a%a}b"
    hv_dbg "[$name] Bound interface $jail_inet_a into bridge $bridge_name"
    cmd ifconfig $bridge_name addm $jail_inet_a
    cmd ifconfig $jail_inet_a up
    hv_dbg "[$name] Generate jail configuration file $jail_ucl_conf_path"
    conf=$(cat $jail_config)
    echo "$name {" > $jail_ucl_conf_path
    hypervisor_append_to_ucl_file $jail_ucl_conf_path mount.fstab $jail_fstab
    hypervisor_append_to_ucl_file $jail_ucl_conf_path vnet.interface "${jail_inet_b}"
    hypervisor_append_to_ucl_file $jail_ucl_conf_path exec.poststop "/sbin/ifconfig $jail_inet_a destroy"
    for p_name in $(hypervisor_jail_config_list_jail_parameters $jail_config) ; do
        p_value=$(hypervisor_jail_config_get_parameter $jail_config $p_name)
        hv_dbg "[$name] Set $p_name = $p_value"
        if [ "$p_value" = "true" ] ; then
            hypervisor_append_to_ucl_file $jail_ucl_conf_path $p_name
        elif [ "$p_value" = "false" ] ; then
            hypervisor_append_to_ucl_file $jail_ucl_conf_path "no$p_name"
        else
            hypervisor_append_to_ucl_file $jail_ucl_conf_path $p_name "$p_value"
        fi
    done
    echo "}" >> $jail_ucl_conf_path
    hv_inf "[$name] Start jail"
    cmd jail -f $jail_ucl_conf_path -c $name
    hv_dbg "[$name] Mount datasets"
    for dpath in $(hypervisor_jail_config_list_datasets $jail_config) ; do
        hv_dbg "[$name] Attach dataset $dpath to jail"
        cmd $ZFS_EXE set jailed=on $dpath
        cmd $ZFS_EXE jail $name $dpath
    done
    hv_inf "[$name] Jail is running"
    return 0
}
hypervisor_jail_stop() {
    local name=$1
    local jail_ucl_conf_path=$(hypervisor_jail_get_ucl_config_path $name)
    local jail_fstab=$(hypervisor_jail_get_fstab_path $name)
    hv_dbg "[$name] Stop jail"
    if ! jls_is_running $name ; then
        hv_err "[$name] No such jail running"
        return 1
    fi
    if [ ! -f $jail_ucl_conf_path ] ; then
        hv_err "[$name] No UCL configuration file for jail. This should not happen"
        return 1
    fi
    cmd jail -f $jail_ucl_conf_path -r $name
    hv_dbg "[$name] Jail is down"
    hv_dbg "[$name] Remove UCL configuration file $jail_ucl_conf_path"
    rm $jail_ucl_conf_path
    hv_dbg "[$name] Remove fstab file $jail_fstab"
    rm $jail_fstab
    hv_inf "[$name] Jail was stopped"
    return 0
}
hypervisor_jail_remove() {
    local name=$1
    local jail_config=$(hypervisor_jail_get_config_path $name)
    local jail_dataset=$(hypervisor_jail_get_dataset_name $name)
    hv_dbg "[$name] Remove jail"
    if [ ! -f $jail_config ] ; then
        hv_err "[$name] $jail_config: no such configuration file"
        return 1
    fi
    if jls_is_running $name ; then
        hv_err "[$name] Jail is still running"
        return 1
    fi
    hv_dbg "[$name] Destroy dataset $jail_dataset"
    cmd $ZFS_EXE destroy -R $jail_dataset
    hv_inf "[$name] Jail was removed"
    return 0
}

# Commands
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
    if ! hypervisor_release_fetch $release_name ; then
        jail_crt "Can't fetch $release_name"
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
                jail_jail_stop $jail_name
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
jail_jail_add() {
    local jail_name=$1
    local release_name=$2
    crt_not_enough_argument 2 $*
    check_release_exists_exit $release_name
    if hypervisor_jail_exists $jail_name ; then
        if force_is_set ; then
            wrn "Jail $jail_name already exists, remove it"
            jail_jail_remove $jail_name
        else
            jail_crt "Jail $jail_name already exists"
        fi
    fi
    if ! hypervisor_jail_create $jail_name $release_name; then
        jail_crt "Can't create jail $jail_name"
    fi
    inf "Jail $jail_name was created"
}
jail_jail_list() {
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
            jail_jail_stop $name
        else
            jail_crt "Jail $name is running"
        fi
    fi
}
jail_jail_remove() {
    crt_not_enough_argument 1 $*
    local jail_name=$1
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    hypervisor_jail_remove $jail_name
    inf "Jail $jail_name was removed"
}
jail_jail_list_with_priority() {
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
jail_jail_list_sort_by_priority() {
    jail_jail_list_with_priority $* | sort -g | cut -f 2 -d " "
}
jail_jail_list_sort_by_priority_reversed() {
    jail_jail_list_with_priority $* | sort -rg | cut -f 2 -d " "
}
jail_jail_start() {
    for jail_name in $(jail_jail_list_sort_by_priority $*) ; do
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
jail_jail_stop() {
    for jail_name in $(jail_jail_list_sort_by_priority_reversed $*) ; do
        if ! jls_is_running $jail_name ; then
            jail_crt "$jail_name is not running"
        else
            hypervisor_jail_stop $jail_name
            inf "Jail $jail_name was stopped"
        fi
    done
}
jail_jail_restart() {
    crt_not_enough_argument 1 $*
    jail_jail_stop $*
    jail_jail_start $*
}
jail_jail_set() {
    crt_not_enough_argument 2 $*
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    parameter_name=$2
    parameter_value=$3
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
    if [ "$parameter_value" = "" ] ; then
        hypervisor_jail_config_remove_parameter $jail_config $parameter_name
        inf "Jail $jail_name parameter $parameter_name was unset"
    else
        hypervisor_jail_config_set_parameter $jail_config $parameter_name $parameter_value
        inf "Jail $jail_name parameter $parameter_name -> $parameter_value"
    fi
}
jail_jail_get() {
    crt_not_enough_argument 2 $*
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    local parameter_name=$2
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    check_jail_is_stopped_exit_or_stop $jail_name
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
    inf "Dataset $dataset was added to jail $jail_name"
}
jail_dataset_list() {
    local jail_name=$1
    local jail_config=$(hypervisor_jail_get_config_path $jail_name)
    check_jail_exists_exit $jail_name
    check_jail_config_exit $jail_name
    hypervisor_jail_config_list_datasets $1
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
}
