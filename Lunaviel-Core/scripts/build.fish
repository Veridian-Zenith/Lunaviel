#!/usr/bin/fish
# Clean previous builds
rm -f BOOTX64.EFI kernel.elf lunaviel.img

# Build UEFI bootloader
zig build-exe aether/aurora.zig -target x86_64-uefi -O ReleaseSmall \
  -femit-bin=BOOTX64.EFI -fno-entry

# Build kernel
zig build-exe aether/sylvar.zig -target x86_64-freestanding-none -O ReleaseSmall \
  -T aether/starlight.ld -femit-bin=kernel.elf

# Only create image if builds succeeded
if test -f BOOTX64.EFI && test -f kernel.elf
    dd if=/dev/zero of=lunaviel.img bs=1M count=64
    mkfs.fat -F 32 lunaviel.img
    mmd -i lunaviel.img ::/EFI ::/EFI/BOOT
    mcopy -i lunaviel.img BOOTX64.EFI ::/EFI/BOOT/
    mcopy -i lunaviel.img kernel.elf ::/
    echo "Build successful!"
else
    echo "Build failed - check compiler errors"
    exit 1
end
