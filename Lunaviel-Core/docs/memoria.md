# Memoria Subsystem Documentation

## Overview
The Memoria subsystem handles memory management in Lunaviel Core with a wave-harmonized approach. It integrates cache optimization, memory synchronization, and resource allocation with the system's wave mechanics.

## Components

### Aetherpage (`aetherpage.zig`)
Memory page management with wave-aware optimization:
- Wave-guided page allocation
- Cache-coherent page mapping
- TLB optimization
- Memory pressure detection

### Harmonia (`harmonia.zig`)
Memory synchronization and cache coherency:
```zig
// Memory fence types
pub const FenceType = enum {
    Load,      // Load fence
    Store,     // Store fence
    Full,      // Full memory fence
    LoadStore, // Load + Store fence
};

// Cache operations
pub const CacheOp = enum {
    Flush,       // Write back and invalidate
    FlushNoWB,   // Invalidate without writeback
    Prefetch,    // Prefetch data
    PrefetchNTA, // Prefetch non-temporal
};
```

### Lunalloc (`lunalloc.zig`)
Wave-harmonized memory allocator:
- Resonance-based allocation
- Cache-aware memory blocks
- Fragmentation prevention
- Resource pressure handling

## Memory Architecture

### Page Management
- 4KB base page size
- Large page support (2MB)
- Huge page support (1GB)
- Wave-optimized page tables

### Cache Optimization
- L1 Cache (80KB per core)
  - Instruction: 32KB
  - Data: 48KB
- L2 Cache (1.5MB shared)
- L3 Cache (10MB shared)

### Memory Synchronization
- Cache coherency protocol
- Memory ordering control
- Atomic operations
- Fence operations

## Wave Integration

### Memory Wave Patterns
- Allocation waves
- Access patterns
- Cache utilization
- Memory pressure

### Resource Harmonization
```zig
pub fn harmonizeMemory() !void {
    // Update memory wave state
    try updateMemoryWave();

    // Optimize cache usage
    optimizeCacheFlow();

    // Handle memory pressure
    balanceResources();
}
```

## Cache Management

### Cache Control Operations
```zig
pub fn cache_op(op: CacheOp, addr: [*]u8, size: usize) void {
    switch (op) {
        .Flush => flushCache(addr, size),
        .FlushNoWB => invalidateCache(addr, size),
        .Prefetch => prefetchData(addr),
        .PrefetchNTA => prefetchNonTemporal(addr),
    }
}
```

### Cache Optimization
- Prefetch prediction
- Write-back optimization
- Cache line alignment
- Access pattern detection

## Memory Flow Control

### Resource Monitoring
- Memory usage tracking
- Cache hit rates
- Page fault patterns
- TLB effectiveness

### Pressure Management
- Page reclamation
- Cache eviction
- Memory compaction
- Swap optimization

## Development Guidelines

### Memory Management
1. Use wave-aware allocations
2. Implement cache optimization
3. Handle synchronization
4. Monitor resource pressure

### Cache Optimization
1. Align data structures
2. Use appropriate prefetch
3. Manage coherency
4. Track cache patterns

### Error Handling
1. Memory allocation failures
2. Cache coherency issues
3. Page fault handling
4. Resource exhaustion

## Performance Considerations

### Optimization Techniques
- Cache-line alignment
- Page coloring
- TLB optimization
- Access pattern analysis

### Resource Efficiency
- Memory pooling
- Cache utilization
- Page sharing
- Fragment prevention

## Future Development

### Planned Features
- Advanced wave prediction
- Dynamic cache partitioning
- Intelligent prefetching
- Enhanced pressure handling

### Research Areas
- Wave pattern analysis
- Cache optimization
- Memory prediction
- Resource harmonization

## API Reference

### Memory Operations
```zig
// Memory allocation
pub fn allocate(size: usize) ![]u8;

// Page management
pub fn mapPages(virt: usize, phys: usize, count: usize) !void;

// Cache control
pub fn controlCache(op: CacheOp, addr: *anyopaque) void;

// Memory synchronization
pub fn syncMemory(fence: FenceType) void;
```

### Wave Integration
```zig
// Memory wave update
pub fn updateMemoryWave() !void;

// Resource optimization
pub fn optimizeResources() void;

// Pressure handling
pub fn handlePressure() !void;
```
