set -e .

SCRIPTNAME=$(basename $0)
COMMON_PATH="$(dirname $0)/exec_common.sh"
if [ ! -f $COMMON_PATH ] ; then
    echo "!!!!! Common code is not defined" > /dev/stderr
    exit 1
fi
. $COMMON_PATH
load_environment

dbg "[$YABH_JAIL_NAME] Execute created script"
# Attach interfaces
for if_str in $(yabh_run jail interface list $YABH_JAIL_NAME) ; do
    if_name=$(csvline_get_field 1 "$if_str")
    if ! inet_if_exists $if_name ; then
        crt 1 "$if_name: No such interface"
    fi
    dbg "[$YABH_JAIL_NAME] Attach interface $if_name"
    cmd ifconfig $if_name vnet $YABH_JAIL_NAME
done
# Mount datasets
for d_str in $(yabh_run jail dataset list $YABH_JAIL_NAME) ; do
    dpath=$(csvline_get_field 1 "$d_str")
    if ! zfs_dataset_exists $dpath ; then
        crt 1 "$dpath: no such dataset"
    fi
    dbg "[$YABH_JAIL_NAME] Attach dataset $dpath to jail"
    cmd zfs set jailed=on $dpath
    cmd zfs jail $YABH_JAIL_NAME $dpath
done
dbg Success
