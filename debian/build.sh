#!/bin/bash

quilt push -a
r=$?
if [ $r -ne 0 -a $r -ne 2 ] ; then
    exit $r
fi

debian_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
root_dir=$(dirname "$debian_dir")

set -e

NUM_JOBS=$((`grep -c '^processor' /proc/cpuinfo` + 1))
export DEB_BUILD_OPTIONS="parallel=$NUM_JOBS"

export `dpkg-architecture -aarmel`
if [ $DEB_BUILD_GNU_TYPE != $DEB_HOST_GNU_TYPE ] ; then
    export DEB_BUILD_PROFILES="cross"
fi

r_clean=
r_source=
while getopts "cs" o; do
    case $o in
    c)
        r_clean=y
        ;;
    s)
        r_source=y
        ;;
    esac
done

if [ -n "$r_clean" -o -n "$r_source" ] ; then
    fakeroot make -f debian/rules clean
    if [ -n "$r_source" ] ; then
        dpkg-source -b .
    fi
fi

fakeroot make -f debian/rules binary
