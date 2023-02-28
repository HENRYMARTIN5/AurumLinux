#!/bin/bash

# This script is used to take a built kernel image and initrd(rootfs) and create a bootable ISO image.

# Check if the required programs are installed
if ! command -v xorriso &> /dev/null
then
    echo "xorriso could not be found"
    exit
fi
if ! command -v grub-mkrescue &> /dev/null
then
    echo "grub-mkrescue could not be found"
    exit
fi

# Check if the kernel image and initrd(rootfs) exist
if [ ! -f bzImage ]; then
    echo "bzImage not found"
    exit
fi
if [ ! -d initrd ]; then
    echo "initrd not found"
    exit
fi

# Create the ISO image
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "AurumLinux" -eltorito-boot boot/grub/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-catalog boot/grub/boot.cat -output AurumLinux.iso ./boot ./bzImage ./initrd