_jq() {
    data=$1
    req=$2
    args=$3
    echo "$data" | jq $args "$req"
}

jqr() {
    _jq "$1" "$2" -r
}

jqc() {
    _jq $1 $2 -c
}
jq_edit() {
    path=$1
    req=$2
    path_tmp="$path.tmp"
    jq "$req" $path > $path_tmp
    mv $path_tmp $path
}


has_key() {
    conf=$1
    key=$2
    test "$(jqr "$conf" "has(\"$key\")")" = "true"
}

is_empty() {
    conf=$1
    key=$2
    test $(jqr "$conf" ".$key | length") -eq 0
}

# Use a global variable as configuration
CONFIGURATION_PATH=""

configuration_load() {
    path=$1
    dbg "Load configuration from $path"
    if [ ! -f $path ] ; then
        crt $RETURN_CONFIGURATION_ERROR "$path: no such file"
    fi
    # Stupid way to check if this a valid JSON file
    cat $path | jq > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        crt $RETURN_CONFIGURATION_ERROR "$path is not a valid JSON file"
    fi
    CONFIGURATION_PATH=$path
}

check_configuration_has_key_exit() {
    conf="$1"
    key=$2
    dbg "Check that configuration key $key exists"
    if ! has_key "$conf" "$key" ; then
        crt $RETURN_CONFIGURATION_ERROR "Configuration $CONFIGURATION_PATH: key $key does not exists"
    fi
}
check_configuration_has_key_non_empty_exit() {
    conf="$1"
    key=$2
    check_configuration_has_key_exit "$conf" "$key"
    if [ "$(jqr "$conf" ".$key")" == "" ] ; then
        crt $RETURN_CONFIGURATION_ERROR "Configuration $CONFIGURATION_PATH: key $key should not be empty"
    fi
}

check_configuration() {
    dbg "Check configuration file $CONFIGURATION_PATH"
    conf=$(cat $CONFIGURATION_PATH)
    check_configuration_has_key_non_empty_exit "$conf" "main_interface"
    check_configuration_has_key_non_empty_exit "$conf" "bridge_interface"
    check_configuration_has_key_non_empty_exit "$conf" "dataset"
}

configuration_get_main_interface() {
    jqr "$(cat $CONFIGURATION_PATH)" ".main_interface"
}
configuration_get_bridge_interface() {
    jqr "$(cat $CONFIGURATION_PATH)" ".bridge_interface"
}
configuration_get_dataset() {
    jqr "$(cat $CONFIGURATION_PATH)" ".dataset"
}
