pub const Task = struct {
    id: usize,
    state: enum { Dormant, Active, Sleeping },
    memory_location: usize,
};

pub var task_list: [32]Task = undefined;

pub fn registerTask(memory: usize) usize {
    var new_id = task_list.len;
    task_list[new_id] = Task{
        .id = new_id,
        .state = .Active,
        .memory_location = memory,
    };
    return new_id;
}
