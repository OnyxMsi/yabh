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
hypervisor_jail_create_skeleton() {
    local name=$1
    local release=$2
    local jail_root=$(hypervisor_jail_get_root_path $name)
    local jail_dataset=$(hypervisor_jail_get_dataset_name $name)
    local release_root=$(hypervisor_release_get_root_path $release)
    hv_dbg "[$name] Create jail dataset $jail_dataset"
    cmd $ZFS_EXE create -p $jail_dataset
    hv_dbg "[$name] Create jail skeleton at $jail_root"
    mkdir -p $jail_root
    mkdir -p "$jail_root/dev"
    mkdir -p "$jail_root/tmp"
    chmod 777 "$jail_root/tmp"
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
}
hypervisor_jail_create_rc_conf() {
    local name=$1
    local jail_root=$(hypervisor_jail_get_root_path $name)
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
}
hypervisor_jail_create_configuration_file() {
    local name=$1
    local release=$2
    local jail_root=$(hypervisor_jail_get_root_path $name)
    local jail_config=$(hypervisor_jail_get_config_path $name)
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
        "exec.stop": "/bin/sh /etc/rc.shutdown jail"
    }
}
EOF
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
    if ! hypervisor_jail_create_skeleton $name $release ; then
        hv_err "[$name] Can't create jail skeleton"
        return 1
    fi
    if ! hypervisor_jail_create_rc_conf $name ; then
        hv_err "[$name] Can't create jail rc.conf"
        return 1
    fi
    if ! hypervisor_jail_create_configuration_file $name $release ; then
        hv_err "[$name] Can't create jail configuration file"
        return 1
    fi
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
# Works only when jail is running
hypervisor_jail_get_host_interface_name() {
    echo "$1.a"
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
hypervisor_jail_generate_fstab() {
    local name=$1
    local jail_config=$(hypervisor_jail_get_config_path $name)
    local jail_release=$(hypervisor_jail_config_get_release $jail_config)
    local jail_fstab=$(hypervisor_jail_get_fstab_path $name)
    local release_root=$(hypervisor_release_get_root_path $jail_release)
    if [ -f $jail_fstab ] ; then
        hv_wrn "[$name] fstab file $jail_fstab exists, that means jail was not stopped properly"
    fi
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
}
hypervisor_jail_generate_configuration_file() {
    local name=$1
    local jail_inet_b=$2
    local jail_config=$(hypervisor_jail_get_config_path $name)
    local jail_fstab=$(hypervisor_jail_get_fstab_path $name)
    local conf=$(cat $jail_config)
    local jail_ucl_conf_path=$(hypervisor_jail_get_ucl_config_path $name)
    if [ -f $jail_ucl_conf_path ] ; then
        hv_wrn "[$name] UCL configuration file $jail_ucl_conf_path exists, that means jail was not stopped properly"
    fi
    hv_dbg "[$name] Generate jail configuration file $jail_ucl_conf_path"
    echo "$name {" > $jail_ucl_conf_path
    hypervisor_append_to_ucl_file $jail_ucl_conf_path mount.fstab $jail_fstab
    hypervisor_append_to_ucl_file $jail_ucl_conf_path vnet.interface "${jail_inet_b}"
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
}
hypervisor_jail_start() {
    local name=$1
    local jail_config=$(hypervisor_jail_get_config_path $name)
    local jail_root=$(hypervisor_jail_get_root_path $name)
    local bridge_name=$(configuration_get_bridge_interface)
    local jail_ucl_conf_path=$(hypervisor_jail_get_ucl_config_path $name)
    local jail_inet_a_new_name
    local jail_inet_b_new_name="epair0b"
    local jail_inet_a
    local jail_inet_b
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
    hv_dbg "[$name] Create interface"
    jail_inet_a=$(ifconfig epair create)
    jail_inet_b="${jail_inet_a%a}b"
    jail_inet_a_new_name=$(hypervisor_jail_get_host_interface_name $name)
    hv_dbg "[$name] Rename interface $jail_inet_a -> $jail_inet_a_new_name"
    cmd ifconfig $jail_inet_a name $jail_inet_a_new_name
    hv_dbg "[$name] Rename interface $jail_inet_b -> $jail_inet_b_new_name"
    cmd ifconfig $jail_inet_b name $jail_inet_b_new_name
    hv_dbg "[$name] Bound interface $jail_inet_a_new_name into bridge $bridge_name"
    cmd ifconfig $bridge_name addm $jail_inet_a_new_name
    cmd ifconfig $jail_inet_a_new_name up
    if ! hypervisor_jail_generate_fstab $name $release_name; then
        hv_err "[$jail_name] Can't generate jail configuration file"
        return 1
    fi
    if ! hypervisor_jail_generate_configuration_file $name $jail_inet_b_new_name ; then
        hv_err "[$jail_name] Can't generate jail configuration file"
        return 1
    fi
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
    local jail_host_if=$(hypervisor_jail_get_host_interface_name $name)
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
    hv_dbg "[$name] Destroy host interface $jail_host_if"
    cmd ifconfig $jail_host_if destroy
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
    cmd $ZFS_EXE destroy -Rf $jail_dataset
    hv_inf "[$name] Jail was removed"
    return 0
}
