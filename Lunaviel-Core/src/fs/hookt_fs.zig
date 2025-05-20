const std = @import("std");
const nvme = @import("../drivers/nvme_driver.zig");
const pulse = @import("../kernel/pulse.zig");
const event_system = @import("../kernel/event_system.zig");
const io_flow = @import("../kernel/io_flow.zig");

/// HooktFS - Direct hardware access filesystem with wave-harmonized I/O
pub const HooktFS = struct {
    // Core components
    driver: *nvme.NVMeDriver,
    allocator: *std.mem.Allocator,
    wave_state: pulse.WaveState,

    // Block management
    block_size: u32,
    total_blocks: u64,
    blocks_used: u64,
    block_bitmap: []u8,

    // File tracking
    const MAX_FILES = 65536;
    const INODE_BLOCKS_START = 1; // Block 0 reserved for superblock
    const DATA_BLOCKS_START = 257; // First 256 blocks reserved for inodes

    const FileFlags = packed struct {
        read_only: bool,
        system: bool,
        hidden: bool,
        encrypted: bool,
        compressed: bool,
        _padding: u11 = 0,
    };

    const Inode = packed struct {
        id: u32,
        size: u64,
        flags: FileFlags,
        direct_blocks: [12]u64,
        indirect_block: u64,
        double_indirect: u64,
        created_at: u64,
        modified_at: u64,
        resonance: f32,
        wave_phase: f32,
        checksum: u32,
    };

    pub fn init(driver: *nvme.NVMeDriver, allocator: *std.mem.Allocator) !HooktFS {
        const total_blocks = try driver.getTotalBlocks();
        const bitmap_size = (total_blocks + 7) / 8;

        var fs = HooktFS{
            .driver = driver,
            .allocator = allocator,
            .block_size = 4096,
            .total_blocks = total_blocks,
            .blocks_used = 0,
            .block_bitmap = try allocator.alloc(u8, bitmap_size),
            .wave_state = .{
                .amplitude = 50,
                .phase = 0,
                .frequency = 1.0,
                .resonance = 0.5,
            },
        };

        // Initialize block bitmap
        @memset(fs.block_bitmap, 0);

        // Mark system blocks as used
        var i: usize = 0;
        while (i < DATA_BLOCKS_START) : (i += 1) {
            fs.markBlockUsed(i);
        }

        try fs.initializeSuperblock();
        return fs;
    }

    pub fn format(self: *HooktFS) !void {
        // Zero out all blocks
        var zero_block: [4096]u8 = .{0} ** 4096;

        var i: u64 = 0;
        while (i < self.total_blocks) : (i += 1) {
            try self.driver.writeBlocks(i, 1, &zero_block);
        }

        // Reset block bitmap
        @memset(self.block_bitmap, 0);

        // Mark system blocks
        i = 0;
        while (i < DATA_BLOCKS_START) : (i += 1) {
            self.markBlockUsed(i);
        }

        // Initialize fresh superblock
        try self.initializeSuperblock();

        // Reset wave state
        self.wave_state = .{
            .amplitude = 50,
            .phase = 0,
            .frequency = 1.0,
            .resonance = 0.5,
        };
    }

    pub fn createFile(
        self: *HooktFS,
        name: []const u8,
        flags: FileFlags
    ) !FileHandle {
        // Validate filename
        if (name.len > 255) return error.NameTooLong;
        if (name.len == 0) return error.InvalidName;

        // Find free inode
        const inode_id = try self.findFreeInode();

        // Initialize inode
        var inode = Inode{
            .id = inode_id,
            .size = 0,
            .flags = flags,
            .direct_blocks = .{0} ** 12,
            .indirect_block = 0,
            .double_indirect = 0,
            .created_at = @bitCast(u64, std.time.milliTimestamp()),
            .modified_at = @bitCast(u64, std.time.milliTimestamp()),
            .resonance = self.wave_state.resonance,
            .wave_phase = self.wave_state.phase,
            .checksum = 0,
        };

        // Write inode
        try self.writeInode(inode_id, &inode);

        // Create and return file handle
        return FileHandle.init(self, inode_id, flags);
    }

    pub fn openFile(self: *HooktFS, inode_id: u32) !FileHandle {
        const inode = try self.readInode(inode_id);
        return FileHandle.init(self, inode_id, inode.flags);
    }

    pub fn deleteFile(self: *HooktFS, inode_id: u32) !void {
        var inode = try self.readInode(inode_id);

        // Free all blocks
        for (inode.direct_blocks) |block| {
            if (block != 0) {
                self.freeBlock(block);
            }
        }

        if (inode.indirect_block != 0) {
            try self.freeIndirectBlock(inode.indirect_block);
            self.freeBlock(inode.indirect_block);
        }

        if (inode.double_indirect != 0) {
            try self.freeDoubleIndirectBlock(inode.double_indirect);
            self.freeBlock(inode.double_indirect);
        }

        // Clear inode
        @memset(@ptrCast([*]u8, &inode), 0, @sizeOf(Inode));
        try self.writeInode(inode_id, &inode);
    }

    const FileHandle = struct {
        fs: *HooktFS,
        inode_id: u32,
        flags: FileFlags,
        position: u64,
        wave_state: pulse.WaveState,

        pub fn init(fs: *HooktFS, inode_id: u32, flags: FileFlags) FileHandle {
            return .{
                .fs = fs,
                .inode_id = inode_id,
                .flags = flags,
                .position = 0,
                .wave_state = fs.wave_state,
            };
        }

        pub fn read(self: *FileHandle, buffer: []u8) !usize {
            const inode = try self.fs.readInode(self.inode_id);

            if (self.position >= inode.size) {
                return 0;
            }

            const to_read = @minimum(
                buffer.len,
                inode.size - self.position
            );

            var bytes_read: usize = 0;
            while (bytes_read < to_read) {
                const block_offset = self.position % self.fs.block_size;
                const block_index = self.position / self.fs.block_size;

                const block = try self.fs.getFileBlock(&inode, block_index);
                if (block == 0) break;

                var block_buffer: [4096]u8 = undefined;
                try self.fs.readBlockWithResonance(
                    block,
                    &block_buffer,
                    self.wave_state.resonance
                );

                const chunk_size = @minimum(
                    self.fs.block_size - block_offset,
                    to_read - bytes_read
                );

                @memcpy(
                    buffer[bytes_read..][0..chunk_size],
                    block_buffer[block_offset..][0..chunk_size]
                );

                bytes_read += chunk_size;
                self.position += chunk_size;
            }

            // Update wave state based on read performance
            self.wave_state.resonance =
                (self.wave_state.resonance * 0.9) +
                (@intToFloat(f32, bytes_read) / @intToFloat(f32, to_read) * 0.1);

            return bytes_read;
        }

        pub fn write(self: *FileHandle, data: []const u8) !usize {
            if (self.flags.read_only) return error.ReadOnlyFile;

            var inode = try self.fs.readInode(self.inode_id);
            var bytes_written: usize = 0;

            while (bytes_written < data.len) {
                const block_offset = self.position % self.fs.block_size;
                const block_index = self.position / self.fs.block_size;

                // Allocate new block if needed
                var block = try self.fs.getFileBlock(&inode, block_index);
                if (block == 0) {
                    block = try self.fs.allocateBlock();
                    try self.fs.setFileBlock(&inode, block_index, block);
                }

                var block_buffer: [4096]u8 = undefined;
                if (block_offset > 0) {
                    // Read existing block content
                    try self.fs.readBlockWithResonance(
                        block,
                        &block_buffer,
                        self.wave_state.resonance
                    );
                }

                const chunk_size = @minimum(
                    self.fs.block_size - block_offset,
                    data.len - bytes_written
                );

                @memcpy(
                    block_buffer[block_offset..][0..chunk_size],
                    data[bytes_written..][0..chunk_size]
                );

                // Write block with wave-harmonized I/O
                try self.fs.writeBlockWithWave(
                    block,
                    &block_buffer,
                    &self.wave_state
                );

                bytes_written += chunk_size;
                self.position += chunk_size;
            }

            // Update inode
            if (self.position > inode.size) {
                inode.size = self.position;
            }
            inode.modified_at = @bitCast(u64, std.time.milliTimestamp());
            inode.resonance = self.wave_state.resonance;
            inode.wave_phase = self.wave_state.phase;
            try self.fs.writeInode(self.inode_id, &inode);

            return bytes_written;
        }

        pub fn seek(self: *FileHandle, offset: i64, origin: enum { Start, Current, End }) !void {
            const inode = try self.fs.readInode(self.inode_id);

            const new_pos = switch (origin) {
                .Start => offset,
                .Current => @bitCast(i64, self.position) + offset,
                .End => @bitCast(i64, inode.size) + offset,
            };

            if (new_pos < 0) return error.InvalidOffset;
            self.position = @bitCast(u64, new_pos);
        }

        pub fn sync(self: *FileHandle) !void {
            var inode = try self.fs.readInode(self.inode_id);
            inode.resonance = self.wave_state.resonance;
            inode.wave_phase = self.wave_state.phase;
            try self.fs.writeInode(self.inode_id, &inode);
        }
    };

    fn initializeSuperblock(self: *HooktFS) !void {
        const Superblock = packed struct {
            magic: u32,
            version: u32,
            block_size: u32,
            total_blocks: u64,
            inode_blocks: u32,
            data_blocks: u64,
            last_mount: u64,
            wave_state: pulse.WaveState,
            checksum: u32,
        };

        var superblock = Superblock{
            .magic = 0x486F6B74, // "Hokt"
            .version = 1,
            .block_size = self.block_size,
            .total_blocks = self.total_blocks,
            .inode_blocks = INODE_BLOCKS_START,
            .data_blocks = self.total_blocks - DATA_BLOCKS_START,
            .last_mount = @bitCast(u64, std.time.milliTimestamp()),
            .wave_state = self.wave_state,
            .checksum = 0,
        };

        // Calculate checksum
        superblock.checksum = self.calculateChecksum(
            @ptrCast([*]const u8, &superblock)[0..@sizeOf(Superblock)]
        );

        // Write superblock
        var block: [4096]u8 = .{0} ** 4096;
        @memcpy(block[0..@sizeOf(Superblock)], @ptrCast([*]const u8, &superblock));
        try self.driver.writeBlocks(0, 1, &block);
    }

    fn readInode(self: *HooktFS, id: u32) !Inode {
        if (id >= MAX_FILES) return error.InvalidInode;

        const block = INODE_BLOCKS_START + (id / (self.block_size / @sizeOf(Inode)));
        const offset = (id % (self.block_size / @sizeOf(Inode))) * @sizeOf(Inode);

        var block_buffer: [4096]u8 = undefined;
        try self.driver.readBlocks(block, 1, &block_buffer);

        var inode = @ptrCast(*Inode, &block_buffer[offset]).*;

        // Verify checksum
        const stored_checksum = inode.checksum;
        inode.checksum = 0;
        const calculated_checksum = self.calculateChecksum(
            @ptrCast([*]const u8, &inode)[0..@sizeOf(Inode)]
        );

        if (stored_checksum != calculated_checksum) {
            return error.InodeCorrupted;
        }

        return inode;
    }

    fn writeInode(self: *HooktFS, id: u32, inode: *Inode) !void {
        if (id >= MAX_FILES) return error.InvalidInode;

        // Calculate checksum
        inode.checksum = 0;
        inode.checksum = self.calculateChecksum(
            @ptrCast([*]const u8, inode)[0..@sizeOf(Inode)]
        );

        const block = INODE_BLOCKS_START + (id / (self.block_size / @sizeOf(Inode)));
        const offset = (id % (self.block_size / @sizeOf(Inode))) * @sizeOf(Inode);

        var block_buffer: [4096]u8 = undefined;
        try self.driver.readBlocks(block, 1, &block_buffer);

        @memcpy(
            block_buffer[offset..][0..@sizeOf(Inode)],
            @ptrCast([*]const u8, inode),
            @sizeOf(Inode)
        );

        try self.driver.writeBlocks(block, 1, &block_buffer);
    }

    fn findFreeInode(self: *HooktFS) !u32 {
        var id: u32 = 0;
        while (id < MAX_FILES) : (id += 1) {
            const inode = try self.readInode(id);
            if (inode.size == 0) {
                return id;
            }
        }
        return error.NoFreeInodes;
    }

    fn allocateBlock(self: *HooktFS) !u64 {
        var block: u64 = DATA_BLOCKS_START;
        while (block < self.total_blocks) : (block += 1) {
            if (!self.isBlockUsed(block)) {
                self.markBlockUsed(block);
                self.blocks_used += 1;
                return block;
            }
        }
        return error.NoFreeBlocks;
    }

    fn freeBlock(self: *HooktFS, block: u64) void {
        if (block >= DATA_BLOCKS_START) {
            self.markBlockUnused(block);
            self.blocks_used -= 1;
        }
    }

    fn isBlockUsed(self: *HooktFS, block: u64) bool {
        const byte = block / 8;
        const bit = @intCast(u3, block % 8);
        return (self.block_bitmap[byte] & (@as(u8, 1) << bit)) != 0;
    }

    fn markBlockUsed(self: *HooktFS, block: u64) void {
        const byte = block / 8;
        const bit = @intCast(u3, block % 8);
        self.block_bitmap[byte] |= (@as(u8, 1) << bit);
    }

    fn markBlockUnused(self: *HooktFS, block: u64) void {
        const byte = block / 8;
        const bit = @intCast(u3, block % 8);
        self.block_bitmap[byte] &= ~(@as(u8, 1) << bit);
    }

    fn getFileBlock(self: *HooktFS, inode: *const Inode, index: u64) !u64 {
        if (index < 12) {
            return inode.direct_blocks[index];
        }

        const indirect_index = index - 12;
        if (indirect_index < self.block_size / 8) {
            if (inode.indirect_block == 0) return 0;

            var block_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(inode.indirect_block, 1, &block_buffer);

            return @ptrCast(*[512]u64, &block_buffer)[indirect_index];
        }

        // Double indirect blocks
        const double_indirect_index = indirect_index - (self.block_size / 8);
        if (double_indirect_index < (self.block_size / 8) * (self.block_size / 8)) {
            if (inode.double_indirect == 0) return 0;

            const primary_index = double_indirect_index / (self.block_size / 8);
            const secondary_index = double_indirect_index % (self.block_size / 8);

            var primary_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(inode.double_indirect, 1, &primary_buffer);

            const secondary_block = @ptrCast(*[512]u64, &primary_buffer)[primary_index];
            if (secondary_block == 0) return 0;

            var secondary_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(secondary_block, 1, &secondary_buffer);

            return @ptrCast(*[512]u64, &secondary_buffer)[secondary_index];
        }

        return error.BlockIndexOutOfBounds;
    }

    fn setFileBlock(self: *HooktFS, inode: *Inode, index: u64, block: u64) !void {
        if (index < 12) {
            inode.direct_blocks[index] = block;
            return;
        }

        const indirect_index = index - 12;
        if (indirect_index < self.block_size / 8) {
            if (inode.indirect_block == 0) {
                inode.indirect_block = try self.allocateBlock();
            }

            var block_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(inode.indirect_block, 1, &block_buffer);

            @ptrCast(*[512]u64, &block_buffer)[indirect_index] = block;
            try self.driver.writeBlocks(inode.indirect_block, 1, &block_buffer);
            return;
        }

        // Double indirect blocks
        const double_indirect_index = indirect_index - (self.block_size / 8);
        if (double_indirect_index < (self.block_size / 8) * (self.block_size / 8)) {
            if (inode.double_indirect == 0) {
                inode.double_indirect = try self.allocateBlock();
            }

            const primary_index = double_indirect_index / (self.block_size / 8);
            const secondary_index = double_indirect_index % (self.block_size / 8);

            var primary_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(inode.double_indirect, 1, &primary_buffer);

            var secondary_block = @ptrCast(*[512]u64, &primary_buffer)[primary_index];
            if (secondary_block == 0) {
                secondary_block = try self.allocateBlock();
                @ptrCast(*[512]u64, &primary_buffer)[primary_index] = secondary_block;
                try self.driver.writeBlocks(inode.double_indirect, 1, &primary_buffer);
            }

            var secondary_buffer: [4096]u8 = undefined;
            try self.driver.readBlocks(secondary_block, 1, &secondary_buffer);

            @ptrCast(*[512]u64, &secondary_buffer)[secondary_index] = block;
            try self.driver.writeBlocks(secondary_block, 1, &secondary_buffer);
            return;
        }

        return error.BlockIndexOutOfBounds;
    }

    fn readBlockWithResonance(self: *HooktFS, block: u64, buffer: []u8, resonance: f32) !void {
        // Adjust read timing based on resonance
        const delay = @floatToInt(u32, (1.0 - resonance) * 1000);
        if (delay > 0) {
            try std.time.sleep(delay * std.time.microsecond);
        }

        try self.driver.readBlocks(block, 1, buffer);
    }

    fn writeBlockWithWave(self: *HooktFS, block: u64, buffer: []const u8, wave: *pulse.WaveState) !void {
        // Adjust write parameters based on wave state
        wave.amplitude = @floatToInt(u8,
            std.math.min(100.0, wave.amplitude * wave.resonance)
        );

        try self.driver.writeBlocksWithWave(block, 1, buffer, wave.*);

        // Update wave resonance based on write success
        wave.resonance = (wave.resonance * 0.9) + 0.1;
    }

    fn calculateChecksum(self: *HooktFS, data: []const u8) u32 {
        _ = self;
        var checksum: u32 = 0;
        for (data) |byte| {
            checksum = checksum *% 33 +% byte;
        }
        return checksum;
    }
};
