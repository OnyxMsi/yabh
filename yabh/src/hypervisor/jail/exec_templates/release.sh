set -e .

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
idx=0
while : ; do
    if_name="${YABH_JAIL_NAME}.${idx}a"
    if ! inet_if_exists $if_name ; then
        break
    fi
    dbg "[$YABH_JAIL_NAME] Destroy interface $if_name"
    ifconfig $if_name destroy || true
done
