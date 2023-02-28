#!/bin/bash

source config.sh

echo "Downloading LFS packagelist..."
wget $LFS_PACKAGELIST -O wget-list-sysv

echo "Downloading LFS packages and patches..."
mkdir -p ./rootfs/sources
wget --input-file=wget-list-sysv --continue --directory-prefix=./rootfs/sources

echo "Downloading LFS md5sums..."
wget $MD5SUMS -O md5sums

echo "Checking md5sums..."
pushd ./rootfs/sources
    md5sum -c md5sums
popd

echo "Packages downloaded and verified."

echo "You may be prompted for your password. If needed, enter it."

echo "Creating rootfs skeleton and setting \$LFS..."
sudo mkdir -p ./rootfs/{bin,etc,lib,sbin,usr,var}

for i in bin lib sbin; do
    sudo ln -sv ./rootfs/usr/$i ./rootfs/$i
done

LFS=$(pwd)/rootfs

case $(uname -m) in
  x86_64) sudo mkdir -pv $LFS/lib64 ;;
esac

echo "Preparing tools..."
sudo mkdir -pv $LFS/tools

echo "Creating lfs user..."
sudo groupadd lfs
sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs

sudo chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) sudo chown -v lfs $LFS/lib64 ;;
esac

echo "Environment has been set up. Run the following commands to continue:
sudo su - lfs
./lfs.sh"