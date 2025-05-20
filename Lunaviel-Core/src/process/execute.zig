pub fn activateTask(task_id: usize) void {
    const task = task_list[task_id];
    if (task.state == .Dormant) return;

    asm volatile (
        "mov %0, %%cr3"
        :: "r"(task.memory_location)
    );

    asm volatile (
        "jmp %0"
        :: "r"(task.memory_location)
    );
}
