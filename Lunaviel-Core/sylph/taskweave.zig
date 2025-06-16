const std = @import("std");
const Allocator = std.mem.Allocator;
const log = @import("../seer/oracle.zig").log;

pub const TaskState = enum {
    Ready,
    Running,
    Blocked,
    Sleeping,
    Terminated
};

pub const TaskContext = packed struct {
    // General purpose registers
    rax: u64 = 0,
    rbx: u64 = 0,
    rcx: u64 = 0,
    rdx: u64 = 0,
    rsi: u64 = 0,
    rdi: u64 = 0,
    rsp: u64 = 0,
    rbp: u64 = 0,
    r8: u64 = 0,
    r9: u64 = 0,
    r10: u64 = 0,
    r11: u64 = 0,
    r12: u64 = 0,
    r13: u64 = 0,
    r14: u64 = 0,
    r15: u64 = 0,

    // Special registers
    rip: u64 = 0,
    rflags: u64 = 0x202, // IF flag set by default
    cs: u64 = 0x8,
    ss: u64 = 0x10,
};

pub const Task = struct {
    id: u32,
    name: [32]u8,
    state: TaskState,
    priority: u8,
    context: TaskContext,
    stack: []u8,
    stack_pointer: usize,
    sleep_until: u64, // For sleeping tasks
    parent_id: ?u32,
    children: std.ArrayList(u32),

    pub fn init(allocator: *Allocator, id: u32, name: []const u8, stack_size: usize, priority: u8) !*Task {
        var task = try allocator.create(Task);

        // Initialize name
        var task_name: [32]u8 = [_]u8{0} ** 32;
        const len = @min(name.len, 31);
        std.mem.copy(u8, task_name[0..len], name[0..len]);

        // Allocate stack
        const stack = try allocator.alloc(u8, stack_size);

        task.* = Task{
            .id = id,
            .name = task_name,
            .state = .Ready,
            .priority = priority,
            .context = TaskContext{},
            .stack = stack,
            .stack_pointer = @ptrToInt(stack.ptr) + stack_size,
            .sleep_until = 0,
            .parent_id = null,
            .children = std.ArrayList(u32).init(allocator),
        };

        log("Created new task");
        return task;
    }

    pub fn deinit(self: *Task, allocator: *Allocator) void {
        allocator.free(self.stack);
        self.children.deinit();
        allocator.destroy(self);
        log("Destroyed task");
    }

    pub fn setup_stack_frame(self: *Task, entry: fn() void) void {
        // Setup initial stack frame
        const stack_top = @ptrToInt(self.stack.ptr) + self.stack.len;
        var stack_frame = @intToPtr(*TaskContext, stack_top - @sizeOf(TaskContext));

        stack_frame.* = TaskContext{
            .rip = @ptrToInt(entry),
            .rsp = stack_top - @sizeOf(TaskContext),
            .rbp = stack_top - @sizeOf(TaskContext),
        };

        self.context = stack_frame.*;
        self.stack_pointer = @ptrToInt(stack_frame);
    }

    pub fn sleep(self: *Task, milliseconds: u64) void {
        const current_time = @import("../astral/sysluna.zig").get_system_time();
        self.sleep_until = current_time + milliseconds;
        self.state = .Sleeping;
        log("Task going to sleep");
    }

    pub fn wake_if_ready(self: *Task) void {
        if (self.state == .Sleeping) {
            const current_time = @import("../astral/sysluna.zig").get_system_time();
            if (current_time >= self.sleep_until) {
                self.state = .Ready;
                log("Task waking up");
            }
        }
    }

    pub fn add_child(self: *Task, child_id: u32) !void {
        try self.children.append(child_id);
    }

    pub fn remove_child(self: *Task, child_id: u32) void {
        for (self.children.items) |id, i| {
            if (id == child_id) {
                _ = self.children.orderedRemove(i);
                break;
            }
        }
    }
};
