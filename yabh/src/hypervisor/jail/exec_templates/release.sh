set -e .

delete_ifs() {
    local idx=0
    local if_prefix=$1
    while : ; do
        if_name="$if_prefix${idx}a"
        if ! inet_if_exists $if_name ; then
            break
        fi
        dbg "[$YABH_JAIL_NAME] Destroy interface $if_name"
        ifconfig $if_name destroy || true
        idx=$(($idx + 1))
    done
}

SCRIPTNAME=$(basename $0)
COMMON_PATH="$(dirname $0)/exec_common.sh"
if [ ! -f $COMMON_PATH ] ; then
    echo "!!!!! Common code is not defined" > /dev/stderr
    exit 1
fi
. $COMMON_PATH
load_environment

dbg "[$YABH_JAIL_NAME] Execute release script"
# Delete interfaces
delete_ifs epair
delete_ifs "${YABH_JAIL_NAME}."
