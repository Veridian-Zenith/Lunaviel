# Lunaviel Core Documentation

## Overview
Lunaviel Core is an adaptive kernel optimized for Intel i3-1215U hardware, featuring a unique wave-harmonized approach to resource management and system optimization. The kernel utilizes resonance and wave mechanics concepts to maintain system harmony and optimize performance.

## Core Components

### Wave Harmonization System
The wave harmonization system is the heart of Lunaviel, coordinating system resources through wave mechanics:
- **System Pulse**: Global wave coordinator (`pulse.zig`)
- **Flow Control**: Resource flow management (`io_flow.zig`)
- **Resonance Tracking**: System harmony monitoring

### Driver Architecture
The driver subsystem provides a flexible, wave-aware framework for hardware interaction:

#### Driver Types (`driver.zig`)
- Storage
- Network
- Input
- Display
- System

#### Driver States
- Uninitialized
- Active
- Suspended
- Error
- Recovery

#### Driver Flow Management
- Resonance tracking
- Bandwidth optimization
- Latency monitoring
- Error rate tracking
- Wave phase synchronization

#### Driver Registry (`driver_registry.zig`)
- Driver registration and lifecycle management
- Resource tracking
- Capability management
- Event handling

### System Call Interface
Lunaviel provides both standard and wave-harmonized system calls:

#### Standard System Calls
- Process management (exit, fork, exec)
- File operations (read, write, open, close)
- Memory management (mmap, munmap)

#### Wave-Specific System Calls
- `SYS_PULSE`: System pulse interaction
- `SYS_HARMONIZE`: Task harmony adjustment
- `SYS_RESONATE`: Resource resonance control

#### Driver System Calls
- `SYS_DRIVER_QUERY`: Query driver information
- `SYS_DRIVER_CONTROL`: Control driver settings
- `SYS_DRIVER_IO`: Perform I/O operations
- `SYS_DRIVER_STATUS`: Get driver status

### Event System
The event system (`event_system.zig`) manages system-wide event propagation:
- Hardware interrupts
- Driver state changes
- Resource pressure events
- System harmonization events

## Hardware Integration
Optimized for Intel i3-1215U:
- 6 cores (2P + 4E)
- 8 threads
- Cache hierarchy management
  - L1: 80KB per core
  - L2: 1.5MB
  - L3: 10MB

## Development Guidelines

### Driver Development
1. Implement the Driver interface
2. Define capabilities and resources
3. Implement wave harmonization
4. Register with driver registry
5. Implement error handling
6. Add event notifications

### System Call Implementation
1. Define syscall number in `syscall_table.zig`
2. Implement handler function
3. Add error handling
4. Update documentation

### Resource Management
1. Register resources with the system
2. Implement wave harmonization
3. Monitor resource health
4. Handle resource pressure

## Building and Running
```fish
cd scripts
./build.fish      # Build the kernel
./run-qemu.fish   # Run in QEMU
./debug.fish      # Debug mode
```

## Future Development
- Enhanced P/E core optimization
- Advanced cache prediction
- Memory resonance patterns
- Network stack harmonization
- File system wave integration
