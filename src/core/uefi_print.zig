const std = @import("std");

pub const EFI_SYSTEM_TABLE = opaque {};
pub const SIMPLE_TEXT_OUTPUT_PROTOCOL = opaque {};

// Global EFI system table pointer
var efiSystemTable: *const EFI_SYSTEM_TABLE = null;

// Converts ASCII string to UTF-16 buffer in-place
fn asciiToUtf16(ascii: []const u8, utf16_buf: []u16) usize {
    var i: usize = 0;
    while (i < ascii.len and i < utf16_buf.len - 1) : (i += 1) {
        utf16_buf[i] = @intCast(u16, ascii[i]);
    }
    utf16_buf[i] = 0; // null-terminate
    return i;
}

// Function pointer type for UEFI OutputString
const OutputStringFn = fn (this: *const SIMPLE_TEXT_OUTPUT_PROTOCOL, str: [*]const u16) callconv(.C) void;

// Set the EFI system table pointer
pub fn setSystemTable(table: *const EFI_SYSTEM_TABLE) void {
    efiSystemTable = table;
}

// Output string via UEFI console
pub fn uefiPrintString(msg: []const u8) void {
    if (efiSystemTable == null) return;

    // Offsets in EFI_SYSTEM_TABLE for ConOut (platform-specific)
    // On x64, pointer size = 8, ConOut is at offset 48 (6th pointer)
    const conOutPtrPtr = @ptrCast(**const SIMPLE_TEXT_OUTPUT_PROTOCOL, @intToPtr(*const u8, @intFromPtr(efiSystemTable) + 48));
    const conOut = conOutPtrPtr.*;
    if (conOut == null) return;

    // Offset of OutputString in SIMPLE_TEXT_OUTPUT_PROTOCOL is 8 bytes (2nd pointer)
    const outputStringFnPtr = @ptrCast(*const OutputStringFn, @intToPtr(*const u8, @intFromPtr(conOut) + 8));
    const outputStringFn = outputStringFnPtr.*;

    // Buffer for UTF-16 string
    var utf16_buffer: [512]u16 = undefined;
    const len_utf16 = asciiToUtf16(msg, utf16_buffer[0..]);

    outputStringFn(conOut, utf16_buffer[0..len_utf16]);
}
