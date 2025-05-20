pub var pulse_state: enum { Stable, Surge, Recede } = .Stable;

pub fn adjustPulse(load: usize) void {
    if (load > 80) {
        pulse_state = .Surge;
    } else if (load < 20) {
        pulse_state = .Recede;
    } else {
        pulse_state = .Stable;
    }
}
