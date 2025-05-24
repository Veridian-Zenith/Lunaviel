#!/usr/bin/fish
qemu-system-x86_64 \
  -drive file=lunaviel.img,format=raw \
  -bios /usr/share/edk2/x64/OVMF.fd \
  -serial stdio \
  -machine q35 \
  -m 4G \
  -no-reboot
