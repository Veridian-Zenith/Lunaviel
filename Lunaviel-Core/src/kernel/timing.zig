pub fn getCycleCount() u64 {
    var cycle: u64 = undefined;
    asm volatile ("rdtsc" : "=A"(cycle));
    return cycle;
}

pub fn waitCycles(cycles: u64) void {
    const start = getCycleCount();
    while (getCycleCount() - start < cycles) {}
}
