const std = @import("std");

pub const EFI_SYSTEM_TABLE = ?*const u8; // You’ll want to replace with real EFI struct later

var efiSystemTable: EFI_SYSTEM_TABLE = null;

// Stub for Forth entrypoint (to be implemented or linked later)
extern fn efi_main_forth(efiTablePtr: *const u8) void;

// UEFI entrypoint function
pub export fn efi_main(efiTablePtr: *const u8) void {
    efiSystemTable = efiTablePtr;

    // Initialize your print module with system table (we'll define this function)
    uefi_print_set_system_table(efiSystemTable);

    // Print the boot message
    uefi_print_string("Lunaviel Core UEFI Boot\n");

    // Call the Forth bootloader entrypoint
    efi_main_forth(efiTablePtr);
}
