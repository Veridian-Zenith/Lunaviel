const std = @import("std");
const driver = @import("driver.zig");
const io_flow = @import("../kernel/io_flow.zig");
const event_system = @import("../kernel/event_system.zig");

// KIOXIA BG5 NVMe Controller specific constants
const NVMe = struct {
    const ADMIN_QUEUE_SIZE = 32;
    const IO_QUEUE_SIZE = 1024;
    const MAX_TRANSFER_SIZE = 128 * 1024; // 128KB per command
    const DOORBELL_STRIDE = 4;

    const CMD_IDENTIFY = 0x06;
    const CMD_CREATE_IO_QUEUE = 0x01;
    const CMD_SET_FEATURES = 0x09;

    const FEAT_NUM_QUEUES = 0x07;
    const FEAT_ASYNC_EVENT = 0x0B;
    const FEAT_POWER_MGMT = 0x02;
};

const NVMeQueue = struct {
    id: u16,
    size: u32,
    head: u32,
    tail: u32,
    phase: bool,
    entries: [*]u8,
    doorbell: [*]volatile u32,
};

pub const NVMeDriver = struct {
    base: driver.Driver,
    admin_queue: NVMeQueue,
    io_queues: []NVMeQueue,
    namespace_id: u32,
    max_transfer_size: u32,
    features: struct {
        num_queues: u32,
        async_events: bool,
        smart_health: bool,
    },

    pub fn init(io_flow: *io_flow.IOFlow) !NVMeDriver {
        var nvme = NVMeDriver{
            .base = driver.Driver.init(0x02, .Storage, io_flow),
            .admin_queue = undefined,
            .io_queues = undefined,
            .namespace_id = 1,
            .max_transfer_size = NVMe.MAX_TRANSFER_SIZE,
            .features = .{
                .num_queues = 0,
                .async_events = false,
                .smart_health = false,
            },
        };

        try nvme.initialize();
        return nvme;
    }

    fn initialize(self: *NVMeDriver) !void {
        // Reset controller
        try self.resetController();

        // Setup admin queue
        try self.setupAdminQueue();

        // Identify controller and namespace
        try self.identifyController();

        // Setup features
        try self.configureFeatures();

        // Create I/O queues
        try self.setupIOQueues();

        self.base.state = .Active;
    }

    pub fn read(self: *NVMeDriver, buffer: []u8, lba: u64) !void {
        const sectors = (buffer.len + 511) / 512;

        // Split large transfers into max_transfer_size chunks
        var offset: usize = 0;
        while (offset < buffer.len) {
            const chunk_size = std.math.min(
                buffer.len - offset,
                self.max_transfer_size
            );

            try self.base.submitIO(
                buffer[offset..offset + chunk_size],
                lba + @divTrunc(offset, 512),
                .Normal
            );

            offset += chunk_size;
        }
    }

    pub fn write(self: *NVMeDriver, buffer: []const u8, lba: u64) !void {
        const sectors = (buffer.len + 511) / 512;

        // Split large transfers into max_transfer_size chunks
        var offset: usize = 0;
        while (offset < buffer.len) {
            const chunk_size = std.math.min(
                buffer.len - offset,
                self.max_transfer_size
            );

            try self.base.submitIO(
                @intToPtr([*]u8, @ptrToInt(buffer.ptr) + offset)[0..chunk_size],
                lba + @divTrunc(offset, 512),
                .Normal
            );

            offset += chunk_size;
        }
    }

    fn resetController(self: *NVMeDriver) !void {
        // Set CC.EN to 0 to disable controller
        asm volatile (
            \\movl $0, %%eax
            \\movl %[reg], %%edx
            \\outl %%eax, %%dx
            :
            : [reg] "r" (0x14)  // CC register offset
        );

        // Wait for CSTS.RDY to become 0
        while (true) {
            const status = asm volatile (
                \\movl %[reg], %%edx
                \\inl %%dx, %%eax
                : [ret] "={eax}" (-> u32)
                : [reg] "r" (0x1C)  // CSTS register offset
            );
            if ((status & 0x1) == 0) break;
        }

        // Configure controller settings
        asm volatile (
            \\movl $0x460001, %%eax  // Enable NVMe, 4KB page size
            \\movl %[reg], %%edx
            \\outl %%eax, %%dx
            :
            : [reg] "r" (0x14)  // CC register offset
        );
    }

    fn setupAdminQueue(self: *NVMeDriver) !void {
        // Allocate admin queue memory
        const queue_size = NVMe.ADMIN_QUEUE_SIZE * 64; // 64 bytes per entry
        const admin_mem = try std.heap.page_allocator.alignedAlloc(
            u8,
            4096,
            queue_size
        );

        self.admin_queue = .{
            .id = 0,
            .size = NVMe.ADMIN_QUEUE_SIZE,
            .head = 0,
            .tail = 0,
            .phase = true,
            .entries = admin_mem.ptr,
            .doorbell = @intToPtr([*]volatile u32, 0x1000), // Base + 1000h
        };
    }

    fn identifyController(self: *NVMeDriver) !void {
        var cmd = self.prepareCommand(NVMe.CMD_IDENTIFY);
        // Set up identify command parameters
        // ... Command specific setup ...
        try self.submitCommand(&cmd);
    }

    fn configureFeatures(self: *NVMeDriver) !void {
        // Set number of queues
        var cmd = self.prepareCommand(NVMe.CMD_SET_FEATURES);
        cmd.features.num_queues = 16; // Request 16 I/O queues
        try self.submitCommand(&cmd);

        // Enable async events
        cmd = self.prepareCommand(NVMe.CMD_SET_FEATURES);
        cmd.features.async_events = true;
        try self.submitCommand(&cmd);
    }

    fn setupIOQueues(self: *NVMeDriver) !void {
        const num_queues = self.features.num_queues;
        self.io_queues = try std.heap.page_allocator.alloc(NVMeQueue, num_queues);

        for (self.io_queues) |*queue, i| {
            try self.createIOQueue(@intCast(u16, i + 1), NVMe.IO_QUEUE_SIZE);
        }
    }

    fn createIOQueue(self: *NVMeDriver, id: u16, size: u32) !void {
        // Allocate queue memory
        const queue_size = size * 64; // 64 bytes per entry
        const queue_mem = try std.heap.page_allocator.alignedAlloc(
            u8,
            4096,
            queue_size
        );

        const queue = &self.io_queues[id - 1];
        queue.* = .{
            .id = id,
            .size = size,
            .head = 0,
            .tail = 0,
            .phase = true,
            .entries = queue_mem.ptr,
            .doorbell = @intToPtr(
                [*]volatile u32,
                0x1000 + (2 * id * NVMe.DOORBELL_STRIDE)
            ),
        };

        // Create submission queue command
        var cmd = self.prepareCommand(NVMe.CMD_CREATE_IO_QUEUE);
        // ... Set up queue creation parameters ...
        try self.submitCommand(&cmd);
    }

    fn prepareCommand(self: *NVMeDriver, opcode: u8) NVMeCommand {
        return .{
            .opcode = opcode,
            // ... other command fields ...
        };
    }

    fn submitCommand(self: *NVMeDriver, cmd: *const NVMeCommand) !void {
        // Submit to admin queue and wait for completion
        // ... Command submission logic ...
    }
};

const NVMeCommand = struct {
    opcode: u8,
    // ... other command fields ...
};
