#!/bin/fish
if not test -f build/LunavielCore.bin
    echo "Error: Kernel binary not found at build/LunavielCore.bin"
    exit 1
end

set mem (or $argv[1] 512M)
set smp (or $argv[2] 2)
qemu-system-x86_64 -kernel build/LunavielCore.bin -m $mem -smp $smp -serial stdio -enable-kvm -d in_asm,cpu_reset 2>error.txt
