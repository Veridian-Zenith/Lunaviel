const std = @import("std");
const io_flow = @import("../kernel/io_flow.zig");
const event_system = @import("../kernel/event_system.zig");
const pulse = @import("../kernel/pulse.zig");

pub const FileType = enum {
    Regular,
    Directory,
    SymLink,
    Device,
    Socket,
    Pipe,
};

pub const FilePermissions = packed struct {
    read: bool,
    write: bool,
    execute: bool,
    owner_read: bool,
    owner_write: bool,
    owner_execute: bool,
    group_read: bool,
    group_write: bool,
    group_execute: bool,
};

pub const FileAttributes = struct {
    type: FileType,
    permissions: FilePermissions,
    size: u64,
    created: u64,
    modified: u64,
    accessed: u64,
    resonance: f32, // Lunaviel-specific: file's resonance with system pulse
};

pub const FileHandle = struct {
    id: u64,
    attributes: FileAttributes,
    flow: *io_flow.IOFlow,
    pulse_state: pulse.WaveState,

    pub fn init(id: u64, attrs: FileAttributes, flow: *io_flow.IOFlow) FileHandle {
        return .{
            .id = id,
            .attributes = attrs,
            .flow = flow,
            .pulse_state = .{
                .amplitude = 50,
                .phase = 0,
                .frequency = 1.0,
                .resonance = 0.5,
            },
        };
    }

    pub fn read(self: *FileHandle, buffer: []u8) !usize {
        // Harmonize with system pulse before I/O
        self.pulse_state.resonance = self.flow.getCurrentResonance();

        const read_size = try self.flow.readWithResonance(
            buffer,
            self.pulse_state.resonance
        );

        // Update file resonance based on I/O success
        self.attributes.resonance =
            (self.attributes.resonance * 0.8) + (self.pulse_state.resonance * 0.2);

        return read_size;
    }

    pub fn write(self: *FileHandle, data: []const u8) !usize {
        // Adjust flow amplitude based on data size
        self.pulse_state.amplitude =
            @floatToInt(u8, std.math.min(
                100,
                @intToFloat(f32, data.len) / 4096.0 * 100.0
            ));

        const written = try self.flow.writeWithPulse(
            data,
            self.pulse_state
        );

        // Update resonance based on write success ratio
        self.attributes.resonance =
            @intToFloat(f32, written) / @intToFloat(f32, data.len);

        return written;
    }

    pub fn close(self: *FileHandle) void {
        self.flow.finalize();
    }
};

pub const VirtualFileSystem = struct {
    mount_points: std.ArrayList(MountPoint),
    handles: std.AutoHashMap(u64, FileHandle),
    next_handle_id: u64,

    pub fn init(allocator: *std.mem.Allocator) VirtualFileSystem {
        return .{
            .mount_points = std.ArrayList(MountPoint).init(allocator),
            .handles = std.AutoHashMap(u64, FileHandle).init(allocator),
            .next_handle_id = 1,
        };
    }

    pub fn mount(self: *VirtualFileSystem, fs: *FileSystem, path: []const u8) !void {
        try self.mount_points.append(.{
            .fs = fs,
            .path = path,
        });
    }

    pub fn open(self: *VirtualFileSystem, path: []const u8, flags: u32) !FileHandle {
        const mount_point = self.findMountPoint(path) orelse
            return error.NoMountPoint;

        const relative_path = path[mount_point.path.len..];
        const file_attrs = try mount_point.fs.getAttributes(relative_path);

        const handle_id = self.next_handle_id;
        self.next_handle_id += 1;

        var flow = try mount_point.fs.createFlow(relative_path, flags);

        const handle = FileHandle.init(handle_id, file_attrs, flow);
        try self.handles.put(handle_id, handle);

        return handle;
    }

    fn findMountPoint(self: *VirtualFileSystem, path: []const u8) ?*MountPoint {
        // Find the most specific mount point that matches the path
        var best_match: ?*MountPoint = null;
        var best_len: usize = 0;

        for (self.mount_points.items) |*mount_point| {
            if (std.mem.startsWith(u8, path, mount_point.path) and
                mount_point.path.len > best_len) {
                best_match = mount_point;
                best_len = mount_point.path.len;
            }
        }

        return best_match;
    }
};

const MountPoint = struct {
    fs: *FileSystem,
    path: []const u8,
};

pub const FileSystem = struct {
    getAttributes: fn (path: []const u8) FileAttributes,
    createFlow: fn (path: []const u8, flags: u32) io_flow.IOFlow,
    read: fn (path: []const u8, buffer: []u8) usize,
    write: fn (path: []const u8, data: []const u8) usize,
    delete: fn (path: []const u8) void,
    list: fn (path: []const u8) []const []const u8,
};
