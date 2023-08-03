set -e .

SCRIPTNAME=$(basename $0)
COMMON_PATH="$(dirname $0)/exec_common.sh"
if [ ! -f $COMMON_PATH ] ; then
    echo "!!!!! Common code is not defined" > /dev/stderr
    exit 1
fi
. $COMMON_PATH
load_environment

inet_get_next_system_if_name() {
    local if_name
    local idx=0
    while : ; do
        if_name="${YABH_JAIL_NAME}.${idx}a"
        if ! inet_if_exists $if_name ; then
            echo $if_name
            return
        fi
        idx=$(($idx + 1))
    done
}

dbg "[$YABH_JAIL_NAME] Execute prepare script"
# Create interfaces
for if_str in $(yabh_run jail interface list $YABH_JAIL_NAME) ; do
    if_name=$(csvline_get_field 1 "$if_str")
    if_bridge=$(csvline_get_field 2 "$if_str")
    if ! inet_if_exists $if_bridge ; then
        crt 1 "$if_bridge: no such bridge interface"
    fi
    if inet_if_exists $if_name ; then
        crt 1 "$if_name: interface already exists"
    fi
    dbg "[$YABH_JAIL_NAME] Create interface $if_name on $if_bridge"
    if_system_name=$(inet_get_next_system_if_name)
    if_tmp_a_name=$(ifconfig epair create)
    if_tmp_b_name="${if_tmp_a_name%a}b"
    dbg "[$YABH_JAIL_NAME] Rename system interface $if_tmp_a_name -> $if_system_name"
    cmd ifconfig $if_tmp_a_name name $if_system_name up
    dbg "[$YABH_JAIL_NAME] Rename jail interface $if_tmp_b_name -> $if_name"
    cmd ifconfig $if_tmp_b_name name $if_name
    dbg "[$YABH_JAIL_NAME] Set interface $if_system_name part of bridge $if_bridge"
    cmd ifconfig $if_bridge addm $if_system_name up
done
# Mount datasets
for d_str in $(yabh_run jail dataset list $YABH_JAIL_NAME) ; do
    dpath=$(csvline_get_field 1 "$d_str")
    dbg "[$YABH_JAIL_NAME] Attach dataset $dpath to jail"
    cmd zfs set jailed=on $dpath
    cmd zfs jail $YABH_JAIL_NAME $dpath
done
dbg Success
