#!/bin/bash

BUSYBOX_VERSION=1.32.1
LINUX_VERSION=5.15.6
BASH_VERSION=5.2.15

echo "Building for Busybox $BUSYBOX_VERSION, Linux $LINUX_VERSION, and Bash $BASH_VERSION"

echo "Cleaning up..."
./clean.sh

mkdir -p src
cd src
    
    # Kernel
    echo "Downloading kernel $LINUX_VERSION..."
    LINUX_MAJOR=$(echo $LINUX_VERSION | sed 's/\([0-9]*\)[^0-9].*/\1/')
    wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$LINUX_MAJOR.x/linux-$LINUX_VERSION.tar.xz
    echo "Extracting kernel..."
    tar -xf linux-$LINUX_VERSION.tar.xz
    echo "Building kernel..."
    cd linux-$LINUX_VERSION
        make defconfig
        make -j$(nproc) || exit
    cd ..

    # Busybox
    echo "Downloading busybox $BUSYBOX_VERSION..."
    wget https://www.busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2  
    echo "Extracting busybox..."  
    tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
    echo "Building busybox..."
    cd busybox-$BUSYBOX_VERSION
        make defconfig
        sed 's/^.*CONFIG_STATIC[^_].*$/CONFIG_STATIC=y/g' -i .config
        make -j$(nproc) || exit
    cd ..

cd ..

echo "Copying kernel..."
cp src/linux-$LINUX_VERSION/arch/x86_64/boot/bzImage ./

# initrd
mkdir initrd
cd initrd

    echo "Creating rootfs skeleton and installing busybox..."
    mkdir -p bin dev proc sys boot
    cd bin
        cp ../../src/busybox-$BUSYBOX_VERSION/busybox ./

        for prog in $(./busybox --list); do
            # Skip bash
            if [ "$prog" = "bash" ]; then
                continue
            fi
            ln -s /bin/busybox ./$prog
        done
    cd ..
cd ..

cd src
    echo "Downloading bash $BASH_VERSION..."
    wget https://ftp.gnu.org/gnu/bash/bash-$BASH_VERSION.tar.gz
    echo "Extracting bash..."
    tar -xf bash-$BASH_VERSION.tar.gz
    echo "Building bash..."
    cd bash-$BASH_VERSION
        ./configure --prefix=/usr --without-bash-malloc
        make -j$(nproc) || exit
        make install DESTDIR=../initrd
    cd ..
cd ..

cd initrd
    echo "Performing final config..."

    echo 'clear' > .bashrc
    echo 'echo "   _____                             .____    .__                     "' >> .bashrc
    echo 'echo "  /  _  \\  __ _________ __ __  _____ |    |   |__| ____  __ _____  ___"' >> .bashrc
    echo 'echo " /  /_\\  \\|  |  \\_  __ \\  |  \\/     \\|    |   |  |/    \\|  |  \\  \\/  /"' >> .bashrc
    echo 'echo "/    |    \\  |  /|  | \\/  |  /  Y Y  \\    |___|  |   |  \\  |  />    < "' >> .bashrc
    echo 'echo "\\____|__  /____/ |__|  |____/|__|_|  /_______ \\__|___|  /____//__/\\_ \\"' >> .bashrc
    echo 'echo "        \\/                         \\/        \\/       \\/            \\/"' >> .bashrc
    echo 'echo ""' >> .bashrc
    echo 'alias ls="ls --color=auto"' >> .bashrc
    echo 'alias l="ls -lah"' >> .bashrc
    echo 'function mkcd() {' >> .bashrc
    echo '  mkdir -p "$@" && cd "$@"' >> .bashrc
    echo '}' >> .bashrc

    echo '#!/bin/bash' > init
    echo 'dmesg -n 1' >> init
    echo 'mount -t devtmpfs none /dev' >> init
    echo 'mount -t proc none /proc' >> init
    echo 'mount -t sysfs none /sys' >> init
    echo 'setsid cttyhack /bin/bash' >> init
    echo 'poweroff -f' >> init

    chmod -R 777 .

    echo "Packing initrd..."
    find . | cpio -o -H newc > ../initrd.img
cd ..

echo "Done!"