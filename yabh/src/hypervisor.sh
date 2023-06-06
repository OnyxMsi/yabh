hypervisor_get_dataset_root() {
    configuration_get_dataset
}
hypervisor_get_dataset_iso() {
    echo "$(hypervisor_get_dataset_root)/isos"
}
hypervisor_get_dataset_release() {
    echo "$(hypervisor_get_dataset_root)/releases"
}
hypervisor_get_dataset_snapshot() {
    echo "$(hypervisor_get_dataset_root)/snapshots"
}
hypervisor_get_dataset_jail() {
    echo "$(hypervisor_get_dataset_root)/jails"
}
hypervisor_get_dataset_vm() {
    echo "$(hypervisor_get_dataset_root)/vms"
}

check_hypervisor() {
    dbg "Check hypervisor configuration"
    # Dataset
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_root)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_iso)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_release)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_snapshot)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_jail)
    check_zfs_dataset_exists_exit $(hypervisor_get_dataset_vm)
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
    create_zfs_dataset_if_not $(hypervisor_get_dataset_root)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_iso)
    cmd zfs set exec=off $(hypervisor_get_dataset_iso)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_release)
    cmd zfs set exec=off $(hypervisor_get_dataset_release)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_snapshot)
    cmd zfs set exec=off $(hypervisor_get_dataset_snapshot)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_jail)
    create_zfs_dataset_if_not $(hypervisor_get_dataset_vm)
    cmd zfs set exec=off $(hypervisor_get_dataset_vm)
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
hypervisor_release_get_dataset() {
    echo "$(hypervisor_get_dataset_release)/$1"
}
hypervisor_release_get_root_path() {
    echo "/$(hypervisor_release_get_dataset $1)/root"
}
hypervisor_release_exists() {
    zfs_dataset_exists $(hypervisor_release_get_dataset $1)
}
hypervisor_release_fetch() {
    local name=$1
    hv_dbg "[$name] Fetch release"
    if hypervisor_release_exists $name ; then
        hv_err "[$name] Release already exists"
        return 1
    fi
    release_url="$HYPERVISOR_RELEASE_BASE_URL/$name"
    release_dataset=$(hypervisor_release_get_dataset $name)
    hv_dbg "[$name] Create zfs dataset $release_dataset"
    cmd zfs create -p $release_dataset
    cmd zfs set exec=off $release_dataset
    release_root=$(hypervisor_release_get_root_path $name)
    release_fetch="/$release_dataset/fetch"
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
    cmd zfs set readonly=on $release_dataset
    hv_inf "[$name] Release $name fetched"
}
hypervisor_release_remove() {
    local name=$1
    local release_dataset=$(hypervisor_release_get_dataset $name)
    if ! hypervisor_release_exists $name ; then
        hv_err "[$name] no such release"
    fi
    hv_dbg "[$name] Remove release $release_dataset"
    cmd zfs destroy -Rf $release_dataset
    hv_inf "[$name] Release was removed"
}
hypervisor_release_list() {
    list_zfs_dataset_children $(hypervisor_get_dataset_release)
}
# Jail
hypervisor_jail_get_dataset() {
    echo "$(hypervisor_get_dataset_jail)/$1"
}
hypervisor_jail_get_root_path() {
    echo "/$(hypervisor_jail_get_dataset $1)/root"
}
hypervisor_jail_get_config_path() {
    echo "/$(hypervisor_jail_get_dataset $1)/config.json"
}
hypervisor_jail_get_ucl_config_path() {
    echo "/$(hypervisor_jail_get_dataset $1)/jail.conf"
}
hypervisor_jail_get_fstab_path() {
    echo "/$(hypervisor_jail_get_dataset $1)/fstab"
}
hypervisor_jail_get_vnet_if_name() {
    local name=$1
    echo "epair_$name"
}
hypervisor_jail_exists() {
    zfs_dataset_exists $(hypervisor_jail_get_dataset $1)
}
hypervisor_jail_list() {
    list_zfs_dataset_children $(hypervisor_get_dataset_jail)
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
    local jail_dataset=$(hypervisor_jail_get_dataset $name)
    local release_root=$(hypervisor_release_get_root_path $release)
    hv_dbg "[$name] Create jail dataset $jail_dataset"
    cmd zfs create -p $jail_dataset
    jail_root=$(hypervisor_jail_get_root_path $name)
    hv_dbg "[$name] Create jail skeleton at $jail_root"
    mkdir -p $jail_root
    mkdir -p "$jail_root/dev"
    mkdir -p "$jail_root/tmp"
    mkdir -p "$jail_root/usr/local"
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
    "release": "$release",
    "datasets": [
    ],
    "priority": 0,
    "parameters": {
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
    conf=$(cat $conf_path)
    if ! has_key "$conf" "release" ; then
        hv_err "[$jail_name] No release in configuration"
        return 1
    fi
    release=$(hypervisor_jail_config_get_release $conf_path)
    if ! hypervisor_release_exists $release ; then
        hv_err "[$jail_name] Unknown release $release"
        return 1
    fi
    if ! has_key "$conf" "parameters" ; then
        hv_err "[$jail_name] No parameters in configuration"
        return 1
    fi
    if ! has_key "$conf" "datasets" ; then
        hv_err "[$jail_name] No datasets in configuration"
        return 1
    fi
    hv_dbg "[$jail_name] Configuration file is OK"
}
hypervisor_jail_config_get_release() {
    local conf_path=$1
    jq -r ".release" $conf_path
}
hypervisor_jail_config_set_parameter() {
    local conf_path=$1
    local parameter_name=$2
    local parameter_value=$3
    jq_edit $conf_path ".parameters[\"$parameter_name\"] = \"$parameter_value\""
}
hypervisor_jail_config_get_parameter() {
    local conf_path=$1
    local parameter_name=$2
    jq -r ".parameters[\"$parameter_name\"]" $conf_path
}
hypervisor_jail_config_has_parameter() {
    local conf_path=$1
    local parameter_name=$2
    test $(jq ".parameters | has(\"$parameter_name\")" $conf_path) = true
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
    jq_edit $conf_path "del(.parameters[\"$parameter_name\"])"
}
hypervisor_jail_config_list_parameters() {
    local conf_path=$1
    jq -r ".parameters | keys | .[]" $conf_path
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
    test $(jq ".datasets | index(\"$dataset\")" $conf_path) != "null"
}
hypervisor_jail_config_has_datasets() {
    local conf_path=$1
    test $(jq ".datasets | length" $conf_path) -gt 0
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
    jq -r ".datasets | .[]" $conf_path
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
    for p_name in $(hypervisor_jail_config_list_parameters $jail_config) ; do
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
        cmd zfs set jailed=on $dpath
        cmd zfs jail $name $dpath
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
    local jail_dataset=$(hypervisor_jail_get_dataset $name)
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
    cmd zfs destroy -R $jail_dataset
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
    hypervisor_jail_list
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
jail_jail_start() {
    local jails
    if [ $# -eq 0 ] ; then
        jails=$(hypervisor_jail_list)
    else
        jails="$*"
    fi
    for jail_name in $(echo $jails) ; do
        check_jail_exists_exit $jail_name
        check_jail_config_exit $jail_name
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
    crt_not_enough_argument 1 $*
    for jail_name in $(echo "$*") ; do
        check_jail_exists_exit $jail_name
        check_jail_config_exit $jail_name
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
    for jail_name in $(echo "$*") ; do
        check_jail_exists_exit $jail_name
        check_jail_config_exit $jail_name
        if jls_is_running $jail_name ; then
            jail_jail_stop $jail_name
        fi
        jail_jail_start $jail_name
    done
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
    hypervisor_jail_config_list_datasets $
    hypervisor_release_list
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
