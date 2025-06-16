const std = @import("std");

// Log levels
pub const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Critical,
};

// Log colors for serial output
const Colors = struct {
    const Reset = "\x1b[0m";
    const Red = "\x1b[31m";
    const Green = "\x1b[32m";
    const Yellow = "\x1b[33m";
    const Blue = "\x1b[34m";
    const Magenta = "\x1b[35m";
    const Cyan = "\x1b[36m";
    const White = "\x1b[37m";
};

// Log configuration
const LOG_CONFIG = struct {
    const SERIAL_PORT = 0x3F8;
    const MAX_LOG_SIZE = 4096;
    const TIMESTAMP_ENABLED = true;
    const COLOR_ENABLED = true;
};

// Circular buffer for log storage
var log_buffer: [LOG_CONFIG.MAX_LOG_SIZE]u8 = undefined;
var log_pos: usize = 0;
var log_wrapped: bool = false;

// Serial port initialization
fn init_serial() void {
    // Disable interrupts
    outb(LOG_CONFIG.SERIAL_PORT + 1, 0x00);

    // Enable DLAB to set baud rate
    outb(LOG_CONFIG.SERIAL_PORT + 3, 0x80);

    // Set baud rate to 115200
    // Divisor = 115200 / 9600 = 1
    outb(LOG_CONFIG.SERIAL_PORT + 0, 0x01);
    outb(LOG_CONFIG.SERIAL_PORT + 1, 0x00);

    // 8 bits, no parity, one stop bit
    outb(LOG_CONFIG.SERIAL_PORT + 3, 0x03);

    // Enable FIFO, clear with 14-byte threshold
    outb(LOG_CONFIG.SERIAL_PORT + 2, 0xC7);

    // IRQs enabled, RTS/DSR set
    outb(LOG_CONFIG.SERIAL_PORT + 4, 0x0B);
}

// Serial port I/O functions
fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port)
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

fn serial_write(data: []const u8) void {
    for (data) |byte| {
        // Wait until transmitter is empty
        while ((inb(LOG_CONFIG.SERIAL_PORT + 5) & 0x20) == 0) {}
        outb(LOG_CONFIG.SERIAL_PORT, byte);
    }
}

// Get current timestamp
fn get_timestamp() u64 {
    var timestamp: u64 = undefined;
    asm volatile ("rdtsc"
        : [ret] "={eax}" (timestamp)
    );
    return timestamp;
}

// Format timestamp as string
fn format_timestamp(buffer: []u8) []u8 {
    const timestamp = get_timestamp();
    const seconds = timestamp / 1_000_000_000;
    const millis = (timestamp % 1_000_000_000) / 1_000_000;
    return std.fmt.bufPrint(buffer, "[{d:4}.{d:3}] ", .{ seconds, millis }) catch buffer[0..0];
}

// Get color code for log level
fn get_level_color(level: LogLevel) []const u8 {
    return switch (level) {
        .Debug => Colors.Cyan,
        .Info => Colors.Green,
        .Warning => Colors.Yellow,
        .Error => Colors.Red,
        .Critical => Colors.Magenta,
    };
}

// Get log level prefix
fn get_level_prefix(level: LogLevel) []const u8 {
    return switch (level) {
        .Debug => "DEBUG: ",
        .Info => "INFO: ",
        .Warning => "WARN: ",
        .Error => "ERROR: ",
        .Critical => "CRIT: ",
    };
}

// Add log entry to circular buffer
fn buffer_log(data: []const u8) void {
    if (data.len > LOG_CONFIG.MAX_LOG_SIZE) return;

    // Check if we need to wrap around
    if (log_pos + data.len > LOG_CONFIG.MAX_LOG_SIZE) {
        const first_part = LOG_CONFIG.MAX_LOG_SIZE - log_pos;
        @memcpy(log_buffer[log_pos..], data[0..first_part]);
        @memcpy(log_buffer[0..], data[first_part..]);
        log_pos = data.len - first_part;
        log_wrapped = true;
    } else {
        @memcpy(log_buffer[log_pos..], data);
        log_pos += data.len;
    }
}

// Initialize logging system
pub fn init() void {
    init_serial();
}

// Main logging function
pub fn log(comptime level: LogLevel, comptime format: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    // Add timestamp if enabled
    if (LOG_CONFIG.TIMESTAMP_ENABLED) {
        const timestamp = format_timestamp(buf[pos..]);
        pos += timestamp.len;
    }

    // Add color if enabled
    if (LOG_CONFIG.COLOR_ENABLED) {
        const color = get_level_color(level);
        const color_len = color.len;
        @memcpy(buf[pos..pos + color_len], color);
        pos += color_len;
    }

    // Add level prefix
    const prefix = get_level_prefix(level);
    const prefix_len = prefix.len;
    @memcpy(buf[pos..pos + prefix_len], prefix);
    pos += prefix_len;

    // Format message
    const msg = std.fmt.bufPrint(buf[pos..], format, args) catch return;
    pos += msg.len;

    // Add reset color code and newline if needed
    if (LOG_CONFIG.COLOR_ENABLED) {
        const reset_len = Colors.Reset.len;
        @memcpy(buf[pos..pos + reset_len], Colors.Reset);
        pos += reset_len;
    }
    buf[pos] = '\n';
    pos += 1;

    // Write to serial port
    serial_write(buf[0..pos]);

    // Store in circular buffer
    buffer_log(buf[0..pos]);
}

// Utility logging functions
pub fn debug(comptime format: []const u8, args: anytype) void {
    log(.Debug, format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    log(.Info, format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    log(.Warning, format, args);
}

pub fn err(comptime format: []const u8, args: anytype) void {
    log(.Error, format, args);
}

pub fn critical(comptime format: []const u8, args: anytype) void {
    log(.Critical, format, args);
}

// Get all logs as a string
pub fn get_logs() []const u8 {
    if (!log_wrapped) {
        return log_buffer[0..log_pos];
    } else {
        return log_buffer[log_pos..] ++ log_buffer[0..log_pos];
    }
}

// Clear logs
pub fn clear_logs() void {
    log_pos = 0;
    log_wrapped = false;
    @memset(&log_buffer, 0);
}
