#!/bin/bash

if [ -z "$1" -o ! -d "$1" -o -z "$2" ] ; then
    echo "Usage : $0 <directory> <version string>"
    exit 1
fi

cd $1

echo -n -e \\x11\\x3f\\x3f\\xee > zImage
echo -n -e \\x01\\x35\\xc3\\xe3 >> zImage
echo -n -e \\x11\\x3f\\x2f\\xee >> zImage
echo -n -e \\x00\\x30\\xa0\\xe3 >> zImage
echo -n -e \\x17\\x3f\\x07\\xee >> zImage
cat arch/arm/boot/zImage >> zImage
cat arch/arm/boot/dts/kirkwood-b3.dtb >> zImage
mkimage -A arm -O linux -T kernel -C none \
	-a 0x00008000 -e 0x00008000 \
	-n Linux-$2 -d zImage uImage
rm zImage
