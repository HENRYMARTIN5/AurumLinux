# Aurum Linux

A barebones Linux distribution built from scratch with Busybox at its core.

## Building

To build the distribution, you need to have the following installed (package names are for Ubuntu 20.04 LTS):

- `git`
- `build-essential`
- `fakeroot`
- `libncurses5-dev`
- `libssl-dev`
- `flex`
- `bison`
- `libelf-dev`
- `qemu-system-x86`

A quick way to install all of these is to run the following command:

```bash
sudo apt install git build-essential fakeroot libncurses5-dev libssl-dev flex bison libelf-dev qemu-system-x86
```

Then, run the following commands to build Aurum Linux and load it into QEMU:

```bash
./build.sh
./emu.sh
```

## Booting on real hardware

Currently, a bootable ISO image is not available. However, you can still boot Aurum Linux on real hardware by creating an ISO image from the `initrd` folder and booting it with GRUB.

## License

Aurum Linux is licensed under the ISC license, which is functionally identical to the MIT license. See the `LICENSE` file for more information.
