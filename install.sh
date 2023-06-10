#!/bin/sh
set -e

SCRIPTDIR=$(dirname $0)

INSTALL_DIR=${YABH_INSTALL_DIR:-/usr/local/lib/yabh}
INSTALL_LINK_PATH=${YABH_INSTALL_LINK_PATH:-/usr/local/bin/yabh}
INSTALL_RC_D_PATH=${YABH_INSTALL_RC_D_PATH:-/usr/local/etc/rc.d/yabh}
INSTALL_CONFIGURATION_PATH=${YABH_INSTALL_CONFIGURATION_PATH:-/usr/local/etc/yabh/configuration.json}

rm_if_exists() {
    [ -e $1 ] && rm -rf $1
}
mkdir_if_needed() {
    [ ! -e $1 ] && mkdir -p $1 || /usr/bin/true
}

echo "Install sources in $INSTALL_DIR"
rm_if_exists $INSTALL_DIR
cp -R $SCRIPTDIR/yabh $INSTALL_DIR
echo "Set permissions"
chmod -R 755 $INSTALL_DIR
find $INSTALL_DIR -type f -exec chmod 0644 {} \;

echo "Create executable $INSTALL_LINK_PATH"
rm_if_exists $INSTALL_LINK_PATH
ln -s $INSTALL_DIR/yabh.sh $INSTALL_LINK_PATH
chmod 755 $INSTALL_DIR/yabh.sh

echo "Install rc.d script"
mkdir_if_needed $(dirname $INSTALL_RC_D_PATH)
cp $SCRIPTDIR/tools/rc.d/yabh $INSTALL_RC_D_PATH
chmod 744 $INSTALL_RC_D_PATH

echo "Install default configuration"
mkdir_if_needed $(dirname $INSTALL_CONFIGURATION_PATH)
cp $SCRIPTDIR/example_configuration.json $INSTALL_CONFIGURATION_PATH
