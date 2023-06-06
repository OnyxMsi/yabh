log() {
    LVL=$1
    HDR=$2
    OUT=$3
    shift 3
    [ $VERBOSITY_LEVEL -ge $LVL ] && echo "$PROGNAME [$HDR] $*" > $OUT
}


crt() {
    ret_code=$1 ; shift
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
    COMMAND=$*
    _cmd "$COMMAND"
    eval $COMMAND > /dev/null
    ret=$?
    if [ $ret -ne 0 ] ; then
        err "$COMMAND"
        err "Failed with code $ret"
        exit 3
    fi
}

crt_invalid_command_line() {
    arg_name=$1 ; shift
    arg_value=$1 ; shift
    crt $RETURN_COMMANDLINE_ERROR "Invalid command line $arg_name \"$arg_value\". See $SCRIPTNAME -h"
}
crt_not_enough_argument() {
    count=$1 ; shift
    if [ $# -lt $count ] ; then
        crt $RETURN_COMMANDLINE_ERROR "Not enough argument. See $SCRIPTNAME -h"
    fi
}
