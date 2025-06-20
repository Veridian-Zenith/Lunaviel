#!/usr/bin/env bash
set -euo pipefail

PROJECT=lunaviel-core
ISO_NAME=lunaviel-core.iso
TARGET=x86_64-unknown-none
TOOLCHAIN=nightly-2024

# Ensure environment
sudo pacman -Sy --needed --noconfirm rustup grub xorriso nasm qemu ovmf llvm lld efibootmgr mold make
rustup install nightly
rustup component add rust-src --toolchain nightly
cargo install cargo-xbuild || true

# Clean old build
rm -rf $PROJECT
mkdir -p $PROJECT/.cargo
cd $PROJECT

# Cargo config
cat > .cargo/config.toml <<EOF
[build]
target = "$TARGET"

[unstable]
build-std = ["core", "compiler_builtins"]
build-std-features = ["compiler-builtins-mem"]
EOF

# Root Cargo.toml
cat > Cargo.toml <<EOF
[package]
name = "$PROJECT"
version = "0.1.0"
edition = "2024"
authors = ["Lunaviel Team <core@lunaviel.io>"]
license = "GPL-3.0-or-later"
build = "build.rs"

[lib]
crate-type = ["staticlib"]

[dependencies]
bitflags = "2.4"
spin = "0.9"
x86_64 = { version = "0.14", features = ["instructions"] }
uefi = { version = "0.25", features = ["alloc"] }
acpi = "4.2"
log = "0.4"
volatile = "0.4"
lazy_static = "1.4"
linked_list_allocator = "0.10"
hashbrown = "0.14"
crossbeam = "0.8"
futures-util = "0.3"

[build-dependencies]
target_build_utils = "0.3"
EOF

# Linker script
cat > linker.ld <<'EOF'
ENTRY(efi_main)
SECTIONS {
  . = 0x100000;
  .text : { *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data : { *(.data .data.*) }
  .bss : { *(COMMON) *(.bss .bss.*) }
  /DISCARD/ : { *(.eh_frame) *(.note .note.*) }
}
EOF

# build.rs
cat > build.rs <<'EOF'
use std::{env, fs::File, io::Write, path::PathBuf};
fn main() {
    println!("cargo:rustc-env=TARGET={}", env::var("TARGET").unwrap());
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let ld = out.join("linker.ld");
    let mut f = File::create(&ld).unwrap();
    f.write_all(include_bytes!("linker.ld")).unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=linker.ld");
}
EOF

# Create stub structure
dirs=(src src/arch src/arch/x86_64 src/arch/x86_64/memory src/drivers src/fs src/fs/lunafs src/process src/sync src/syscalls src/utils)
for d in "${dirs[@]}"; do mkdir -p "$d"; done

# Minimal boot.rs
cat > src/boot.rs <<'EOF'
#![no_std]
#![no_main]
#![feature(abi_efiapi)]

use core::panic::PanicInfo;
use uefi::prelude::*;

#[no_mangle]
pub extern "efiapi" fn efi_main(handle: Handle, st: SystemTable<Boot>) -> Status {
    let (_st_rt, _mmap) = st.exit_boot_services(handle, &mut [0u8; 4096]).unwrap();
    unsafe { super::main() }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
EOF

# Minimal main.rs
cat > src/main.rs <<'EOF'
#![no_std]
#![no_main]
#![feature(alloc_error_handler, abi_efiapi)]

extern crate alloc;

mod arch;
mod boot;
mod drivers;
mod fs;
mod memory;
mod process;
mod sync;
mod syscalls;
mod utils;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "efiapi" fn efi_main(_handle: uefi::Handle, _st: uefi::table::SystemTable<uefi::table::Boot>) -> ! {
    boot::efi_main(_handle, _st);
    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}

#[alloc_error_handler]
fn alloc_error(_: core::alloc::Layout) -> ! {
    loop {}
}
EOF

# Build kernel
cargo +nightly xbuild --release

# Create ISO
mkdir -p iso/EFI/BOOT
grub-mkrescue -o $ISO_NAME iso || true

# Done
echo "\n✅ Lunaviel Core ready. ISO: $ISO_NAME"