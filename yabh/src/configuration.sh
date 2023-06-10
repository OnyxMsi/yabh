jq_edit() {
    path=$1
    req=$2
    path_tmp="$path.tmp"
    $JQ_EXE "$req" $path > $path_tmp
    mv $path_tmp $path
}

jq_has_key() {
    local file_path=$1
    local parent_path=$2
    local key=$3
    test $(jq_get $file_path "$parent_path | has(\"$key\")") = true
}
jq_is_empty() {
    local file_path=$1
    local parent_path=$2
    test $(jq_get $file_path "$parent_path | length") -eq 0
}
jq_get() {
    local file_path=$1
    local json_path="$2"
    $JQ_EXE -r "$json_path" $file_path
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
    cat $path | $JQ_EXE > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        crt $RETURN_CONFIGURATION_ERROR "$path is not a valid JSON file"
    fi
    CONFIGURATION_PATH=$path
}

check_configuration_has_key_non_empty_exit() {
    local conf="$1"
    local parent=$2
    local key=$3
    local path
    [ "$parent" = "." ] && path=".$key" || path="$parent.$key"
    if ! jq_has_key $conf "$parent" "$key" ; then
        crt $RETURN_CONFIGURATION_ERROR "Configuration $CONFIGURATION_PATH: key $path does not exists"
    fi
    if jq_is_empty $conf "$path" ; then
        crt $RETURN_CONFIGURATION_ERROR "Configuration $CONFIGURATION_PATH: key $path should not be empty"
    fi
}

check_configuration() {
    dbg "Check configuration file $CONFIGURATION_PATH"
    check_configuration_has_key_non_empty_exit $CONFIGURATION_PATH . main_interface
    check_configuration_has_key_non_empty_exit $CONFIGURATION_PATH . bridge_interface
    check_configuration_has_key_non_empty_exit $CONFIGURATION_PATH . dataset
    check_configuration_has_key_non_empty_exit $CONFIGURATION_PATH .dataset name
    check_configuration_has_key_non_empty_exit $CONFIGURATION_PATH .dataset mountpoint
}

configuration_get_main_interface() {
    jq_get $CONFIGURATION_PATH .main_interface
}
configuration_get_bridge_interface() {
    jq_get $CONFIGURATION_PATH .bridge_interface
}
configuration_get_dataset_name() {
    jq_get $CONFIGURATION_PATH .dataset.name
}
configuration_get_dataset_mountpoint() {
    jq_get $CONFIGURATION_PATH .dataset.mountpoint
}
configuration_get_dataset_path() {
    echo "$(configuration_get_dataset_mountpoint)/$1"
}
