PROGNAME=yabh
VERBOSITY_LEVEL=0

# Return values
RETURN_SUCCESS=0
RETURN_COMMANDLINE_ERROR=1
RETURN_CONFIGURATION_ERROR=2
RETURN_NOT_ROOT_ERROR=3
RETURN_ENVIRONMENT_ERROR=4
RETURN_JAIL_ERROR=5

HYPERVISOR_RELEASE_BASE_URL="https://download.freebsd.org/ftp/releases/amd64"
JAIL_DEFAULT_DEVFSRULESET=5

DEFAULT_LIST_SEPARATOR=","
DEFAULT_JAIL_LIST_FIELDS="host.hostname"
DEFAULT_CONFIGURATION_PATH="/usr/local/etc/$PROGNAME/configuration.json"

JQ_EXE=${YABH_JQ_EXE:-/usr/local/bin/jq}
ZFS_EXE=${YABH_ZFS_EXE:-/sbin/zfs}

RUNTIME_DIRECTORY=$SCRIPTDIR

# Exec templates for jails
HYPERVISOR_JAIL_TEMPLATE_EXEC_PREPARE=$SCRIPTDIR/src/hypervisor/jail/exec_templates/prepare.sh
HYPERVISOR_JAIL_TEMPLATE_EXEC_CREATED=$SCRIPTDIR/src/hypervisor/jail/exec_templates/created.sh
HYPERVISOR_JAIL_TEMPLATE_EXEC_POSTSTOP=$SCRIPTDIR/src/hypervisor/jail/exec_templates/poststop.sh
HYPERVISOR_JAIL_TEMPLATE_EXEC_COMMON=$SCRIPTDIR/src/hypervisor/jail/exec_templates/common.sh
