pub var system_load: usize = 0;

pub fn adjustLoad(pulse_id: usize) void {
    if (pulse_id % 3 == 0) {
        system_load += 5;
    } else if (pulse_id % 7 == 0) {
        system_load -= 3;
    }

    if (system_load > 90) {
        pulseCPU(0x01); // Reduce task intensity
    }
}
