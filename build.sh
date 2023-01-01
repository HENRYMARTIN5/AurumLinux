#!/bin/bash

BUSYBOX_VERSION=1.32.1
LINUX_VERSION=5.15.6

./clean.sh

mkdir -p src
cd src

    # Kernel
    LINUX_MAJOR=$(echo $LINUX_VERSION | sed 's/\([0-9]*\)[^0-9].*/\1/')
    wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$LINUX_MAJOR.x/linux-$LINUX_VERSION.tar.xz
    tar -xf linux-$LINUX_VERSION.tar.xz
    cd linux-$LINUX_VERSION
        make defconfig
        make -j$(nproc) || exit
    cd ..

    # Busybox
    wget https://www.busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2    
    tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
    cd busybox-$BUSYBOX_VERSION
        
        make defconfig
        sed 's/^.*CONFIG_STATIC[^_].*$/CONFIG_STATIC=y/g' -i .config
        make -j$(nproc) || exit

    cd ..
    
cd ..

cp src/linux-$LINUX_VERSION/arch/x86_64/boot/bzImage ./

# initrd
mkdir initrd
cd initrd

    mkdir -p bin dev proc sys boot
    cd bin
        cp ../../src/busybox-$BUSYBOX_VERSION/busybox ./

        for prog in $(./busybox --list); do
            ln -s /bin/busybox ./$prog
        done
    cd ..

    echo 'clear' > .ashrc
    echo 'echo "   _____                             .____    .__                     "' >> .ashrc
    echo 'echo "  /  _  \\  __ _________ __ __  _____ |    |   |__| ____  __ _____  ___"' >> .ashrc
    echo 'echo " /  /_\\  \\|  |  \\_  __ \\  |  \\/     \\|    |   |  |/    \\|  |  \\  \\/  /"' >> .ashrc
    echo 'echo "/    |    \\  |  /|  | \\/  |  /  Y Y  \\    |___|  |   |  \\  |  />    < "' >> .ashrc
    echo 'echo "\\____|__  /____/ |__|  |____/|__|_|  /_______ \\__|___|  /____//__/\\_ \\"' >> .ashrc
    echo 'echo "        \\/                         \\/        \\/       \\/            \\/"' >> .ashrc
    echo 'echo ""' >> .ashrc
    echo 'alias ls="ls --color=auto"' >> .ashrc
    echo 'alias l="ls -lah"' >> .ashrc
    echo 'function mkcd() {' >> .ashrc
    echo '  mkdir -p "$@" && cd "$@"' >> .ashrc
    echo '}' >> .ashrc

    echo '#!/bin/sh' > init
    echo 'dmesg -n 1' >> init
    echo 'mount -t devtmpfs none /dev' >> init
    echo 'mount -t proc none /proc' >> init
    echo 'mount -t sysfs none /sys' >> init
    echo 'setsid cttyhack /bin/sh' >> init
    echo 'poweroff -f' >> init

    chmod -R 777 .

    find . | cpio -o -H newc > ../initrd.img

cd ..