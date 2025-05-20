#!/bin/fish
qemu-system-x86_64 -kernel build/LunavielCore.bin -m 512M -smp 2 -serial stdio -enable-kvm -d in_asm,cpu_reset 2>error.txt
