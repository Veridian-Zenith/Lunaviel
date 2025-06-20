#![no_std]
#![no_main]
#![feature(alloc_error_handler)]

extern crate alloc;

use core::panic::PanicInfo;
use uefi::Handle;
use uefi::table::{SystemTable, Boot};
use uefi::Status;
use linked_list_allocator::LockedHeap;

// Provide a global allocator for heap allocations
#[global_allocator]
static ALLOCATOR: LockedHeap = LockedHeap::empty();

// You must initialize the allocator early in your boot process, e.g.:
// unsafe { ALLOCATOR.lock().init(heap_start as usize, heap_size); }

mod arch;
mod boot;
mod drivers;
mod fs;
mod memory;
mod process;
mod sync;
mod syscalls;
mod utils;

#[no_mangle]
pub extern "efiapi" fn efi_main(_handle: Handle, _st: SystemTable<Boot>) -> ! {
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
