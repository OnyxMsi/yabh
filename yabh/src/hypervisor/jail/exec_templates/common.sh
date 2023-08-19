VERBOSITY_LEVEL=${YABH_VERBOSITY_LEVEL:-0}

if [ "$SCRIPTNAME" = "" ] ; then
    echo "!!!!!!!!!! No SCRIPTNAME is defined"
    exit 51
fi

log() {
    local lvl=$1
    local hdr=$2
    local out=$3
    shift 3
    [ $VERBOSITY_LEVEL -ge $lvl ] && echo "$SCRIPTNAME [$hdr] $*" > $out
    return 0
}
crt() {
    local ret_code=$1 ; shift
    log 0 CRT /dev/stderr $*
    exit $ret_code
}
err() {
    log 0 ERR /dev/stderr $*
}
wrn() {
    log 0 WRN /dev/stdout $*
}
inf() {
    log 1 INF /dev/stdout $*
}
dbg() {
    log 2 DBG /dev/stdout $*
}
_cmd() {
    log 3 CMD /dev/stdout $*
}
cmd() {
    local command=$*
    local ret
    _cmd "$command"
    eval $command > /dev/null
    ret=$?
    if [ $ret -ne 0 ] ; then
        err $command
        err "Failed with code $ret"
        exit 3
    fi
}

csvline_get_field() {
    local field=$1 ; shift
    echo $* | cut -d "," -f $field
}
inet_if_exists() {
    local name=$1
    ifconfig $name > /dev/null 2>&1
}
yabh_run() {
    sh $YABH_DIR/yabh.sh -c $YABH_CONFIGURATION_PATH $@
}

load_environment() {
    ENVIRONMENT_FILE="$(dirname $0)/exec_environment"
    if [ ! -f $ENVIRONMENT_FILE ] ; then
        crt 1 "$ENVIRONMENT_FILE: no such environment"
    fi

    . $ENVIRONMENT_FILE

    if [ ! -d $YABH_DIR ] ; then
        crt 1 "$YABH_DIR: Can't find yabh runtime"
    fi

    if [ "$YABH_JAIL_NAME" = "" ] ; then
        crt 1 "YABH_JAIL_NAME is not defined"
    fi
    if [ "$YABH_CONFIGURATION_PATH" = "" ] ; then
        crt 1 "YABH_CONFIGURATION_PATH is not defined"
    fi
}
zfs_dataset_exists() {
    local name=$1
    zfs list -H -o name | grep --quiet --extended-regexp "\b$name\b"
}
