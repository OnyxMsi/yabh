#!/bin/sh
#
SCRIPTDIR=$(dirname $(realpath $0))
SCRIPTNAME=$(basename $0)

. $SCRIPTDIR/src/constants.sh
. $SCRIPTDIR/src/log.sh
. $SCRIPTDIR/src/configuration.sh
. $SCRIPTDIR/src/system.sh
. $SCRIPTDIR/src/hypervisor.sh

CMD_CHECK=check
CMD_INIT=init
CMD_JAIL=jail
CMD_JAIL_RELEASE=release
CMD_JAIL_RELEASE_ADD=add
CMD_JAIL_RELEASE_REMOVE=remove
CMD_JAIL_RELEASE_LIST=list
CMD_JAIL_DATASET=dataset
CMD_JAIL_DATASET_ADD=add
CMD_JAIL_DATASET_REMOVE=remove
CMD_JAIL_DATASET_LIST=list
CMD_JAIL_JAIL=jail
CMD_JAIL_JAIL_ADD=add
CMD_JAIL_JAIL_REMOVE=remove
CMD_JAIL_JAIL_LIST=list
CMD_JAIL_JAIL_GET=get
CMD_JAIL_JAIL_SET=set
CMD_JAIL_JAIL_START=start
CMD_JAIL_JAIL_RESTART=restart
CMD_JAIL_JAIL_STOP=stop
CMD_JAIL_JAIL_EXPORT=export
CMD_JAIL_SNAPSHOT=snapshot
CMD_JAIL_SNAPSHOT_ADD=add
CMD_JAIL_SNAPSHOT_REMOVE=remove
CMD_JAIL_SNAPSHOT_RESTORE=restore
CMD_JAIL_SNAPSHOT_LIST=list
CMD_VM=vm
CMD_VM_ISO=iso
CMD_VM_ISO_ADD=add
CMD_VM_ISO_REMOVE=remove
CMD_VM_ISO_LIST=list

help() {
    echo "$SCRIPTNAME [-hfv][-c configuration] command ..."
    echo "-h Display this message"
    echo "-f Force"
    echo "-n Do not run check before command (except for check command ...)"
    echo "-v More logging, the more v the more verbose"
    echo "-c Alternative configuration path (default is $DEFAULT_CONFIGURATION_PATH)"
    echo "configuration Path to configuration"
    c="$SCRIPTNAME configuration"
    echo "$c $CMD_CHECK"
    echo "Check system and configuration"
    echo "$c $CMD_INIT"
    echo "Initialize system"
    echo "$c $CMD_JAIL command"
    echo "About jails"
    echo "$c $CMD_JAIL $CMD_JAIL_RELEASE command"
    echo "About jails release's"
    echo "$c $CMD_JAIL $CMD_JAIL_RELEASE $CMD_JAIL_RELEASE_LIST"
    echo "List jail release's"
    echo "$c $CMD_JAIL $CMD_JAIL_RELEASE $CMD_JAIL_RELEASE_ADD release_version"
    echo "Add new release"
    echo "$c $CMD_JAIL $CMD_JAIL_RELEASE $CMD_JAIL_RELEASE_REMOVE release_version"
    echo "Remove release"
    echo "$c $CMD_JAIL $CMD_JAIL_DATASET $CMD_JAIL_DATASET_LIST jail_name"
    echo "List jail datasets"
    echo "$c $CMD_JAIL $CMD_JAIL_DATASET $CMD_JAIL_DATASET_ADD jail_name dataset_name"
    echo "Add new dataset to jail"
    echo "$c $CMD_JAIL $CMD_JAIL_DATASET $CMD_JAIL_DATASET_REMOVE jail_name dataset_name"
    echo "Remove dataset from jail"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL command"
    echo "About jails"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_ADD name release"
    echo "Add new jail"
    echo "name: the name of the jail"
    echo "release: the release to use"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_REMOVE name"
    echo "Remove jail"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_START [name ...]"
    echo "Start jail"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_RESTART [name ...]"
    echo "Restart jail"
    echo "name: the name of the jail (if not set then start every jail)"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_STOP [name ...]"
    echo "Stop jail"
    echo "name: the name of the jail"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_SET name parameter [value]"
    echo "Set jail parameter"
    echo "name: the name of the jail"
    echo "parameter: the name of the parameter to set"
    echo "value: the value of the parameter to set, if empty it will unset it"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_GET name parameter"
    echo "Get jail parameter"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_LIST [-s separator][fields ...]"
    echo "List jails"
    echo "-s Fields separator (default is \"$DEFAULT_LIST_SEPARATOR\")"
    echo "fields ... Fields to show (default is \"$DEFAULT_JAIL_LIST_FIELDS\"). Fields come from jail parameters"
    echo "$c $CMD_JAIL $CMD_JAIL_JAIL $CMD_JAIL_JAIL_EXPORT jail src [dest]"
    echo "Export file into jail"
    echo "jail: Jail name"
    echo "src: File path on host"
    echo "dest: File path on jail. If not set it will be the same as src."
    echo "$c $CMD_JAIL $CMD_JAIL_SNAPSHOT $CMD_JAIL_SNAPSHOT_ADD jail "
    echo "Take a snapshot of the jail"
    echo "jail: Jail name"
    echo "$c $CMD_JAIL $CMD_JAIL_SNAPSHOT $CMD_JAIL_SNAPSHOT_LIST jail "
    echo "List jail snapshots'"
    echo "jail: Jail name"
    echo "$c $CMD_JAIL $CMD_JAIL_SNAPSHOT $CMD_JAIL_SNAPSHOT_REMOVE jail "
    echo "Remove jail snapshot's"
    echo "jail: Jail name"
    echo "$c $CMD_JAIL $CMD_JAIL_SNAPSHOT $CMD_JAIL_SNAPSHOT_RESTORE jail snapshot"
    echo "Restore jail to snapshot's"
    echo "jail: Jail name"
    echo "snapshot: Snapshot identifier"
    echo "$c $CMD_VM command"
    echo "About virtual machines"
    echo "$c $CMD_VM $CMD_VM_ISO"
    echo "About virtual machines ISO's"
    echo "$c $CMD_VM $CMD_VM_ISO $CMD_VM_ISO_ADD name url"
    echo "Add new ISO"
    echo "name: Name of the ISO"
    echo "url: URL to find the ISO"
    echo "$c $CMD_VM $CMD_VM_ISO $CMD_VM_ISO_REMOVE name"
    echo "Remove ISO"
    echo "name: Name of the ISO"
    echo "$c $CMD_VM $CMD_VM_ISO $CMD_VM_ISO_LIST"
    echo "List ISOs"

    echo "$c $CMD_VM_INSTALL [vm_name ...]"
    echo "Install virtual machines from configuration"
    echo " vm_name : install only these virtual machine(s)"
    echo " -f : force, will stop and delete the virtual machine if it exists"
    echo "$c $CMD_VM_REMOVE vm_name ..."
    echo " vm_name : remove virtual machine(s)"
}

force_is_set() {
    test $FORCE != "0"
}

check() {
    check_configuration
    check_system
    check_hypervisor
}
init() {
    init_hypervisor
}
check_if() {
    if [ $NO_CHECK -eq 0 ] ; then
        check "$@"
    else
        wrn "No check option is set"
    fi
}

# jail is already defined
_jail() {
    crt_not_enough_argument 1 "$@"
    CMD=$1 ; shift
    case $CMD in
        $CMD_JAIL_RELEASE) jail_release "$@";;
        $CMD_JAIL_DATASET) jail_dataset "$@";;
        $CMD_JAIL_SNAPSHOT) jail_snapshot "$@";;
        $CMD_JAIL_JAIL) jail_jail "$@";;
        *) crt_invalid_command_line "jail command" $CMD ;;
    esac
}
jail_release() {
    crt_not_enough_argument 1 "$@"
    CMD=$1 ; shift
    case $CMD in
        $CMD_JAIL_RELEASE_ADD) jail_release_add "$@";;
        $CMD_JAIL_RELEASE_REMOVE) jail_release_remove "$@";;
        $CMD_JAIL_RELEASE_LIST) jail_release_list "$@";;
        *) crt_invalid_command_line "jail command" $CMD ;;
    esac
}
jail_dataset() {
    crt_not_enough_argument 1 "$@"
    CMD=$1 ; shift
    case $CMD in
        $CMD_JAIL_DATASET_ADD) jail_dataset_add "$@";;
        $CMD_JAIL_DATASET_REMOVE) jail_dataset_remove "$@";;
        $CMD_JAIL_DATASET_LIST) jail_dataset_list "$@";;
        *) crt_invalid_command_line "jail command" $CMD ;;
    esac
}
jail_snapshot() {
    crt_not_enough_argument 1 "$@"
    CMD=$1 ; shift
    case $CMD in
        $CMD_JAIL_SNAPSHOT_ADD) jail_snapshot_add "$@";;
        $CMD_JAIL_SNAPSHOT_REMOVE) jail_snapshot_remove "$@";;
        $CMD_JAIL_SNAPSHOT_LIST) jail_snapshot_list "$@";;
        $CMD_JAIL_SNAPSHOT_RESTORE) jail_snapshot_restore "$@";;
        *) crt_invalid_command_line "jail command" $CMD ;;
    esac
}
jail_jail() {
    crt_not_enough_argument 1 "$@"
    CMD=$1 ; shift
    case $CMD in
        $CMD_JAIL_JAIL_ADD) jail_jail_add "$@";;
        $CMD_JAIL_JAIL_REMOVE) jail_jail_remove "$@";;
        $CMD_JAIL_JAIL_LIST) jail_jail_list "$@";;
        $CMD_JAIL_JAIL_GET) jail_jail_get "$@";;
        $CMD_JAIL_JAIL_SET) jail_jail_set "$@";;
        $CMD_JAIL_JAIL_START) jail_jail_start "$@";;
        $CMD_JAIL_JAIL_RESTART) jail_jail_restart "$@";;
        $CMD_JAIL_JAIL_STOP) jail_jail_stop "$@";;
        $CMD_JAIL_JAIL_EXPORT) jail_jail_export "$@";;
        *) crt_invalid_command_line "jail command" $CMD ;;
    esac
}
vm() {
}

# Arguments default values
FORCE=0
NO_CHECK=0
LIST_SEPARATOR=$DEFAULT_LIST_SEPARATOR
CONFIGURATION_PATH=$DEFAULT_CONFIGURATION_PATH
while getopts "vhfs:nc:" ARG ; do
    shift
    case "$ARG" in
        h) help ; exit 0 ;;
        f) FORCE=1 ;;
        n) NO_CHECK=1 ;;
        c) CONFIGURATION_PATH=$OPTARG ; shift ;;
        v) VERBOSITY_LEVEL=$(($VERBOSITY_LEVEL + 1)) ;;
        s) LIST_SEPARATOR=$OPTARG ; shift ;;
        --) break ;;
        ?) crt_invalid_command_line argument $ARG ;;
    esac
done
# Checks before process start
if [ $(id -u) -ne 0 ] ; then
    crt $RETURN_NOT_ROOT_ERROR "Must be root"
fi
for dep in $(echo "$JQ_EXE $ZFS_EXE") ; do
    if [ ! -f $dep ] ; then
        crt $RETURN_ENVIRONMENT_ERROR "$dep is required but not found"
    fi
done
crt_not_enough_argument 1 "$@"
configuration_load $CONFIGURATION_PATH
CMD=$1 ; shift
case $CMD in
    $CMD_CHECK) check ;;
    $CMD_INIT) init ;;
    $CMD_JAIL) check_if ; _jail "$@" ;;
    $CMD_VM) check_if ; vm "$@" ;;
    *) crt_invalid_command_line command $CMD ;;
esac
dbg "Success"
exit $RETURN_SUCCESS
