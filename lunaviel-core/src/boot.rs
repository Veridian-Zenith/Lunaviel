use uefi::table::{SystemTable, Boot};
use uefi::Status;
use uefi::{Handle};

// This function is called from main.rs's efi_main
pub fn efi_main(handle: Handle, st: SystemTable<Boot>) -> Status {
    let (_st_rt, _mmap) = st.exit_boot_services(handle, &mut [0u8; 4096]).unwrap();
    // Initialize allocator here if needed
    Status::SUCCESS
}
