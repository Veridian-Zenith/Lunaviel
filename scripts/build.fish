#!/usr/bin/env fish

# Configuration
set KERNEL_NAME "lunaviel"
set BUILD_DIR "build"
set KERNEL_ELF "$BUILD_DIR/$KERNEL_NAME.elf"
set ISO_DIR "$BUILD_DIR/iso"
set ISO_FILE "$BUILD_DIR/$KERNEL_NAME.iso"

# Compiler settings
set ZIG "zig"
set NASM "nasm"
set LD "ld"

# Compiler flags
set ZIG_FLAGS "-target x86_64-freestanding -mcpu=alderlake" # Optimized for i3-1215U
set NASM_FLAGS "-f elf64"
set LD_FLAGS "-n -T aether/starlight.ld --gc-sections"

# Colors for output
set RED '\033[0;31m'
set GREEN '\033[0;32m'
set YELLOW '\033[1;33m'
set NC '\033[0m'

function print_status
    echo -e "$argv[1]$argv[2]$NC"
end

function check_error
    if test $status -ne 0
        print_status $RED "Error: $argv[1]"
        exit 1
    end
end

# Create build directory structure
mkdir -p $BUILD_DIR/objs
mkdir -p $ISO_DIR/boot/grub

# Compile assembly files
print_status $YELLOW "Compiling assembly files..."
$NASM $NASM_FLAGS aether/boot/boot.asm -o $BUILD_DIR/objs/boot.o
check_error "Failed to compile boot.asm"

# Compile Zig files
print_status $YELLOW "Compiling Zig files..."

# Core kernel components
set ZIG_FILES "
    aether/kmain.zig
    aether/aurora.zig
    aether/etherial.zig
    aether/luminary.zig
    aether/sylvar.zig
    memoria/aetherpage.zig
    memoria/lunalloc.zig
    memoria/harmonia.zig
    sylph/moonweave.zig
    sylph/starthread.zig
    sylph/taskweave.zig
    seer/oracle.zig
    astral/sysluna.zig
    astral/celestine.zig
    astral/arcanum.zig
"

for file in (echo $ZIG_FILES)
    set obj_file "$BUILD_DIR/objs/"(basename $file .zig)".o"
    print_status $YELLOW "Compiling $file..."
    $ZIG build-obj $file -o $obj_file $ZIG_FLAGS
    check_error "Failed to compile $file"
end

# Link everything together
print_status $YELLOW "Linking kernel..."
$LD $LD_FLAGS $BUILD_DIR/objs/*.o -o $KERNEL_ELF
check_error "Failed to link kernel"

# Create GRUB config
echo "
menuentry '$KERNEL_NAME' {
    multiboot /boot/$KERNEL_NAME.elf
    boot
}" > $ISO_DIR/boot/grub/grub.cfg

# Copy kernel to ISO directory
cp $KERNEL_ELF $ISO_DIR/boot/

# Create ISO
print_status $YELLOW "Creating bootable ISO..."
grub-mkrescue -o $ISO_FILE $ISO_DIR
check_error "Failed to create ISO"

print_status $GREEN "Build complete! Kernel image: $ISO_FILE"
