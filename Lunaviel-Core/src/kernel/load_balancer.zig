pub var system_load: usize = 0;

pub fn adjustLoad(pulse_id: usize) void {
    if (pulse_id % 3 == 0) {
        system_load = @min(system_load + 5, 100);
    } else if (pulse_id % 7 == 0) {
        system_load = @max(system_load - 3, 0);
    }
}
