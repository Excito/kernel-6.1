#!/bin/bash

quilt push -a
r=$?
if [ $r -ne 0 -a $r -ne 2 ] ; then
    exit $r
fi

set -e

export BUILD_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/_minimal
export CROSS_COMPILE=`dpkg-architecture -aarmel -q DEB_HOST_GNU_TYPE 2>/dev/null`-
export NUM_JOBS=$((`grep -c '^processor' /proc/cpuinfo` + 1))

make ARCH=arm mrproper
make ARCH=arm O=$BUILD_DIR bubba3-minimal_defconfig
make ARCH=arm O=$BUILD_DIR -j$NUM_JOBS zImage
make ARCH=arm O=$BUILD_DIR -j$NUM_JOBS kirkwood-b3.dtb

KERNEL_VERSION=`sed 's/+$//' $BUILD_DIR/include/config/kernel.release`

debian/build_b3_uImage.sh $BUILD_DIR $KERNEL_VERSION

echo "B3 minimal image is ready in $BUILD_DIR/uImage"
