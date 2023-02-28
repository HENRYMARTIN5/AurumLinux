#!/bin/bash

source config.sh

LFS=$(pwd)/rootfs

echo "Writing config files..."

cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

NUMTHREADS=$(nproc)

cat > ~/.bashrc << EOF
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\$LFS/tools/bin:\$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS='-j$NUMTHREADS'
EOF

source ~/.bash_profile

# Begin building
echo "------------ Starting build ------------"
echo "This will take a while. Go get a coffee."

echo "Extracting packages..."
for i in $(ls ./rootfs/sources/*.tar.*); do
    echo "Extracting $i..."
    tar -xf $i -C ./rootfs/sources
done
echo "Done extracting packages."

echo "Building binutils (pass 1)..."
pushd ./rootfs/sources/binutils-2.40
    mkdir -v build
    cd build
    ../configure --prefix=$LFS/tools \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT   \
                 --disable-nls       \
                 --enable-gprofng=no \
                 --disable-werror
    make
    make install
popd
echo "Done building binutils (pass 1)."

echo "Building gcc (pass 1)..."
pushd ./rootfs/sources/gcc-12.2.0
    mv -v mpfr-4.2.0 mpfr
    mv -v gmp-6.2.1 gmp
    mv -v mpc-1.3.1 mpc

    case $(uname -m) in
    x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
    ;;
    esac

    mkdir -v build
    cd build

    ../configure                  \
        --target=$LFS_TGT         \
        --prefix=$LFS/tools       \
        --with-glibc-version=2.37 \
        --with-sysroot=$LFS       \
        --with-newlib             \
        --without-headers         \
        --enable-default-pie      \
        --enable-default-ssp      \
        --disable-nls             \
        --disable-shared          \
        --disable-multilib        \
        --disable-threads         \
        --disable-libatomic       \
        --disable-libgomp         \
        --disable-libquadmath     \
        --disable-libssp          \
        --disable-libvtv          \
        --disable-libstdcxx       \
        --enable-languages=c,c++

    make
    make install
popd
echo "Done building gcc (pass 1)."

echo "Building linux headers..."
pushd ./rootfs/sources/linux-6.1.11
    make mrproper
    make headers
    find usr/include -name '.*' -delete
    rm usr/include/Makefile
    cp -rv usr/include $LFS/usr
popd
echo "Done building linux headers."

echo "Building glibc..."
pushd ./rootfs/sources/glibc-2.37
    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
        ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
        ;;
    esac

    patch -Np1 -i ../glibc-2.37-fhs-1.patch

    mkdir -v build
    cd build

    echo "rootsbindir=/usr/sbin" > configparms

    ../configure                             \
          --prefix=/usr                      \
          --host=$LFS_TGT                    \
          --build=$(../scripts/config.guess) \
          --enable-kernel=3.2                \
          --with-headers=$LFS/usr/include    \
          libc_cv_slibdir=/usr/lib

    make
    make DESTDIR=$LFS install

    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    $LFS/tools/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders
popd
echo "Done building glibc."

echo "Installing Libstdc++..."
pushd ./rootfs/sources/gcc-12.2.0

    mkdir -v build
    cd build

    ../libstdc++-v3/configure           \
        --host=$LFS_TGT                 \
        --build=$(../config.guess)      \
        --prefix=/usr                   \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/12.2.0
    
    make
    make DESTDIR=$LFS install

    rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la
popd
echo "Done installing Libstdc++."

echo "Done building cross-toolchain."

echo "Building cross-compiling temporary tools..."

echo "Building M4..."
pushd ./rootfs/sources/m4-1.4.19
    ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
popd
echo "Done building M4."

echo "Building Ncurses..."
pushd ./rootfs/sources/ncurses-6.4
    sed -i s/mawk// configure
    mkdir build
    pushd build
        ../configure
        make -C include
        make -C progs tic
    popd
    ./configure --prefix=/usr                \
                --host=$LFS_TGT              \
                --build=$(./config.guess)    \
                --mandir=/usr/share/man      \
                --with-manpage-format=normal \
                --with-shared                \
                --without-normal             \
                --with-cxx-shared            \
                --without-debug              \
                --without-ada                \
                --disable-stripping          \
                --enable-widec
    make
    make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
    echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
popd
echo "Done building Ncurses."

echo "Building Bash..."
pushd ./rootfs/sources/bash-5.2.15
    ./configure --prefix=/usr                    \
                --host=$LFS_TGT                  \
                --build=$(./config.guess)        \
                --without-bash-malloc            \
                --with-installed-readline
    make
    make DESTDIR=$LFS install
    ln -sv bash $LFS/bin/sh
popd
echo "Done building Bash."

echo "Building coreutils..."
pushd ./rootfs/sources/coreutils-9.1
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess) \
                --enable-install-program=hostname
    make
    make DESTDIR=$LFS install
    mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
popd
echo "Done building coreutils."

echo "Building Diffutils..."
pushd ./rootfs/sources/diffutils-3.9
    ./configure --prefix=/usr --host=$LFS_TGT
    make
    make DESTDIR=$LFS install
popd
echo "Done building Diffutils."

echo "Building File..."
pushd ./rootfs/sources/file-5.44
    mkdir build
    pushd build
        ../configure --disable-bzlib      \
                     --disable-libseccomp \
                     --disable-xzlib      \
                     --disable-zlib
        make
    popd

    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)

    make FILE_COMPILE=$(pwd)/build/src/file
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/libmagic.la
popd
echo "Done building File."

echo "Building Findutils..."
pushd ./rootfs/sources/findutils-4.9.0
    ./configure --prefix=/usr                   \
                --localstatedir=/var/lib/locate \
                --host=$LFS_TGT                 \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
popd
echo "Done building Findutils."

echo "Building Gawk..."
pushd ./rootfs/sources/gawk-5.2.1
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr   \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
popd
echo "Done building Gawk."