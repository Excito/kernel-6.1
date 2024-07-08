#!/bin/bash

set -eo pipefail

KERNEL_BRANCH=6.1

export DEBEMAIL=leclerc.charles@gmail.com

debian_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
root_dir=$(dirname "$debian_dir")

cd $root_dir

cleanup() {
    echo "Cleanup directory"
    r=0
    quilt push -a || r=$?
    if [ $r -eq 1 ] ; then
        exit 1
    fi
    dpkg-buildpackage -Tclean $B_OPTIONS
    quilt pop -a
}

if [ `dpkg-architecture -aarmel -q DEB_BUILD_GNU_TYPE 2>/dev/null` != `dpkg-architecture -aarmel -q DEB_HOST_GNU_TYPE 2>/dev/null` ] ; then
    echo "Cross build detected"
    B_OPTIONS="-aarmel -Pcross -j$((`nproc` + 1))"
else
    B_OPTIONS="-j$((`nproc` + 1))"
fi

step1() {
    cleanup
    git add -f debian
    if [ -n "`git status --porcelain`" ] ; then
        echo "Uncommited changes in the current tree ! Cannot continue"
        exit 1
    fi
    
    echo "Synchronizing branches"
    git pull --all
    
    release_ver=`curl -s https://www.kernel.org/feeds/kdist.xml | xpath -q -e "//item[starts-with(title, '$KERNEL_BRANCH.')]/title" | sed -e 's/<\/\?title>//g' -e 's/:.*//'`
    current_ver=`dpkg-parsechangelog -S Version | sed -e 's/-.*//'`
    
    new_ver=`echo -e "$release_ver\n$current_ver" | sort -rV | head -n 1`
    
    if [ $new_ver = $current_ver ]; then
        exit 0
    fi
    
    echo "New kernel version available: $new_ver"
    
    k_source=../linux_$new_ver.orig.tar.xz
    if [ ! -e $k_source ] ; then
        echo "Downloading kernel sources"
        curl -s -o ../linux_$new_ver.orig.tar.xz https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$new_ver.tar.xz
    else
        echo "Using existing $k_source"
    fi
    
    echo "Importing upstream sources in git"
    gbp import-orig --no-interactive --color=off $k_source
    
    echo "Appending version in changelog"
    NEW_VERSION=$new_ver-1
    dch -v $NEW_VERSION "New upstream version"
    dch -r ""
    
    echo "Applying and refreshing patches"
    while true ; do
        r=0
        quilt push --refresh || r=$?
        if [ $r -eq 1 ] ; then
            echo "Unable to apply patches"
            exit 1
        elif [ $r -eq 2 ] ; then
            break
        fi
    done
    
    echo "Files ready, creating release commit"
    git add debian
    git commit -m "Released version $NEW_VERSION"
    
    echo "Building package"
    debuild -us -uc -ui $B_OPTIONS
    echo "Installing new kernel and rebooting"
    sudo dpkg -i ../bubba3-kernel_${NEW_VERSION}_armel.deb
    echo -n $NEW_VERSION > ~/kbuild
    sudo reboot
}


step2() {
    cleanup
    NEW_VERSION=`cat ~/kbuild`
    rm ~/kbuild
    echo "Tagging version and pushing git changes"
    gbp buildpackage --git-tag-only
    git push --all
    git push --tags

    echo "Sending and importing package files to the repository"
    scp ../linux_${NEW_VERSION}_armel.changes excito@repo.excito.org:import
    for f in `sed -e '0,/^Files:/d' -e '/^\w/,$d' ../linux_${NEW_VERSION}_armel.changes | awk '{ print $5 }'`; do
        scp -q ../$f excito@repo.excito.org:import
        rm ../$f
    done
    rm ../linux_${NEW_VERSION}_armel.changes
    (cd .. ; gzip linux_${NEW_VERSION}_armel.build)

    ssh excito@repo.excito.org /home/excito/bin/reprepro -b /home/excito/repo --ignore=wrongdistribution include bookworm import/linux_${NEW_VERSION}_armel.changes
    ssh excito@repo.excito.org rm import/*
    
    echo "All done"
}

if [ ! -e ~/kbuild ] ; then
    step1
else
    step2
fi
