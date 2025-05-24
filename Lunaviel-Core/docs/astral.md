# Astral Subsystem Documentation

## Overview
The Astral subsystem manages system calls, userspace interaction, and high-level resource orchestration in Lunaviel Core. It provides the interface between user applications and the wave-harmonized kernel systems.

## Components

### Arcanum (`arcanum.zig`)
System call management:
- Syscall handling
- Permission control
- Resource access
- Wave interaction

### Celestine (`celestine.zig`)
User space interaction:
- Process management
- Memory mapping
- Resource allocation
- Wave synchronization

### Sysluna (`sysluna.zig`)
System interface:
- API definitions
- Resource controls
- Wave management
- Driver interaction

## System Calls

### Core System Calls
```zig
pub const SystemCall = enum(u8) {
    Exit = 0x01,
    Read = 0x02,
    Write = 0x03,
    Open = 0x04,
    Close = 0x05,
    Fork = 0x06,
    Exec = 0x07,
    Mmap = 0x08,
    Munmap = 0x09,
};
```

### Wave-Specific Calls
```zig
pub const WaveCall = enum(u8) {
    Pulse = 0x0A,
    Harmonize = 0x0B,
    Resonate = 0x0C,
};
```

## Driver Interface

### Driver System Calls
```zig
pub const DriverCall = enum(u8) {
    Query = 0x20,
    Control = 0x21,
    IO = 0x22,
    Status = 0x23,
};
```

### Driver Control
- Device management
- Resource allocation
- Flow control
- State management

## Resource Management

### Resource Types
- Memory regions
- File handles
- Device access
- Wave patterns

### Access Control
- Permission levels
- Resource limits
- Wave boundaries
- Flow constraints

## Wave Integration

### Wave Control
```zig
pub fn controlWave(params: WaveParams) !void;
pub fn adjustFlow(flow: *Flow) !void;
pub fn synchronizeWaves() !void;
```

### Resource Flow
```zig
pub fn allocateResource(type: ResourceType) !Resource;
pub fn releaseResource(resource: *Resource) void;
pub fn optimizeFlow(resource: *Resource) !void;
```

## API Reference

### System Interface
```zig
// System call handling
pub fn handleSyscall(call: SystemCall) !void;

// Resource management
pub fn manageResource(resource: *Resource) !void;

// Wave control
pub fn controlSystemWave(wave: *Wave) !void;
```

### User Space Interface
```zig
// Process management
pub fn createProcess(params: ProcessParams) !ProcessId;

// Memory management
pub fn mapMemory(addr: usize, size: usize) ![]u8;

// Resource allocation
pub fn allocateResource(type: ResourceType) !ResourceHandle;
```

## Development Guidelines

### System Call Implementation
1. Define call number
2. Implement handler
3. Add wave support
4. Handle errors

### Resource Management
1. Define resource type
2. Implement allocation
3. Add flow control
4. Monitor usage

### Error Handling
1. Define error types
2. Implement recovery
3. Maintain state
4. Restore harmony

## Security Considerations

### Permission Control
- Access levels
- Resource limits
- Wave boundaries
- Flow restrictions

### Resource Protection
- Memory isolation
- Device access
- Wave separation
- Flow control

## Best Practices

### System Call Design
- Clear interfaces
- Error handling
- Resource tracking
- Wave integration

### Resource Allocation
- Efficient usage
- Flow optimization
- Wave harmony
- Error recovery

### Wave Management
- Pattern monitoring
- Flow control
- Resource harmony
- State tracking

## Future Development

### Planned Features
- Enhanced security
- Advanced wave control
- Improved resources
- Better integration

### Research Areas
- Wave optimization
- Resource efficiency
- Security models
- Flow patterns

## Integration Guide

### System Integration
1. Initialize subsystem
2. Configure resources
3. Set up waves
4. Enable monitoring

### Application Integration
1. Define interfaces
2. Implement calls
3. Handle resources
4. Manage waves

### Error Recovery
1. Detect issues
2. Save state
3. Restore harmony
4. Resume operation
