const std = @import("std");
const event_system = @import("event_system.zig");
const EventQueue = event_system.EventQueue;

var global_event_queue: EventQueue = undefined;
var system_ticks: u64 = 0;
const TICKS_PER_SECOND: u64 = 1000;

pub fn getCycleCount() u64 {
    var high: u32 = undefined;
    const low = asm volatile ("rdtsc"
        : [_] "={eax}" (-> u32),
          [_] "={edx}" (high)
    );
    return (@as(u64, high) << 32) | low;
}

pub fn init() void {
    global_event_queue = EventQueue.init();
    system_ticks = 0;
}

pub fn tick() void {
    system_ticks += 1;
    processTimerEvents();
}

fn processTimerEvents() void {
    if (system_ticks % TICKS_PER_SECOND == 0) {
        queueEvent(.{
            .type = .Timer,
            .priority = .Normal,
            .timestamp = getCycleCount(),
            .data = .{ .timer = .{
                .ticks = system_ticks,
            }},
        });
    }
}

pub fn waitCycles(cycles: u64) void {
    const start = getCycleCount();
    while (getCycleCount() - start < cycles) {
        asm volatile ("pause");
    }
}

pub fn queueEvent(event: event_system.Event) void {
    _ = global_event_queue.push(event);
}

pub fn getNextEvent() ?event_system.Event {
    return global_event_queue.pop();
}

pub fn getPriorityEvent() ?event_system.Event {
    return global_event_queue.peekPriority();
}

pub const Deadline = struct {
    target_time: u64,

    pub fn new(delay_ticks: u64) Deadline {
        return .{
            .target_time = system_ticks + delay_ticks,
        };
    }

    pub fn hasExpired(self: Deadline) bool {
        return system_ticks >= self.target_time;
    }

    pub fn remainingTicks(self: Deadline) u64 {
        if (self.hasExpired()) return 0;
        return self.target_time - system_ticks;
    }
};
