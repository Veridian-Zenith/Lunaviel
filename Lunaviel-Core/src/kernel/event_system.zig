pub const EventType = enum {
    Interrupt,
    Timer,
    KeyboardInput,
    DiskIO,
    ProcessCreated,
    ProcessTerminated,
    MemoryLow,
    SystemOverload,
    HardwareError,
    UserDefined,
    FSMount,
    FSUnmount,
    FSError,
    FSPressure,
    NetworkError,
    NetworkDisharmony,
    NetworkInterface,
    NetworkConnection,
    DriverRegistered,
    DriverUnregistered,
    DriverStateChanged,
    DriverError,
    DriverIO,
};

pub const EventPriority = enum(u8) {
    Critical = 0,
    High = 1,
    Normal = 2,
    Low = 3,
    Background = 4,
};

pub const Event = struct {
    type: EventType,
    priority: EventPriority,
    timestamp: u64,
    data: union {
        interrupt: struct {
            vector: u8,
            error_code: ?u64,
        },
        timer: struct {
            ticks: u64,
        },
        keyboard: struct {
            scancode: u8,
        },
        disk: struct {
            operation: enum { Read, Write },
            sector: u64,
            count: u32,
        },
        process: struct {
            pid: u32,
            status: u32,
        },
        memory: struct {
            available: usize,
            total: usize,
        },
        system: struct {
            load: u8,
            temperature: u8,
        },
        hardware: struct {
            device_id: u16,
            error_code: u32,
        },
        user: struct {
            code: u32,
            data: u64,
        },
        fs_mount: struct {
            path: []const u8,
            fs_type: []const u8,
            resonance: f32,
        },
        fs_unmount: struct {
            path: []const u8,
        },
        fs_error: struct {
            path: []const u8,
            error_code: u32,
        },
        network_error: struct {
            error_code: u32,
            operation: []const u8,
        },
        network: struct {
            interface: []const u8,
            resonance: f32,
        },
        driver_event: struct {
            id: u16,
            type: u8,
        },
        driver_state: struct {
            id: u16,
            old_state: u8,
            new_state: u8,
            resonance: f32,
        },
        driver_io: struct {
            id: u16,
            operation: enum { Read, Write, Control },
            status: u32,
        },
    },
};
