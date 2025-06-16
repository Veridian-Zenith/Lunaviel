const std = @import("std");
const log = @import("oracle.zig");

// Test result types
pub const TestResult = enum {
    Pass,
    Fail,
    Skip,
    Error,
};

// Test case structure
pub const TestCase = struct {
    name: []const u8,
    func: fn() TestResult,
    requires_hardware: bool = false,
    timeout_ms: u32 = 1000,
};

// Test suite structure
pub const TestSuite = struct {
    name: []const u8,
    cases: []const TestCase,
    setup: ?fn() void = null,
    teardown: ?fn() void = null,
};

// Test statistics
const TestStats = struct {
    total: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
    errors: usize = 0,
    duration_ms: u64 = 0,
};

// Hardware capabilities for testing
const HardwareCapabilities = struct {
    has_avx: bool = false,
    has_avx2: bool = false,
    has_sse4_2: bool = false,
    has_aes: bool = false,
    core_count: u32 = 0,
    total_memory: u64 = 0,
    page_size: u32 = 0,
};

// Global test configuration
var test_config = struct {
    verbose: bool = false,
    fail_fast: bool = false,
    hardware_check: bool = true,
    timeout_enabled: bool = true,
}{};

// Hardware capabilities cache
var hw_caps: HardwareCapabilities = undefined;

// Initialize test framework
pub fn init() void {
    if (test_config.hardware_check) {
        detect_hardware_capabilities();
    }
    log.info("Test framework initialized", .{});
}

// Detect hardware capabilities
fn detect_hardware_capabilities() void {
    var caps = HardwareCapabilities{};

    // Detect CPU features
    var max_cpuid: u32 = undefined;
    asm volatile ("cpuid"
        : [max] "={eax}" (max_cpuid),
          [ebx] "={ebx}" (_),
          [ecx] "={ecx}" (_),
          [edx] "={edx}" (_)
        : [leaf] "{eax}" (0)
    );

    if (max_cpuid >= 1) {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        var edx: u32 = undefined;

        asm volatile ("cpuid"
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx)
            : [leaf] "{eax}" (1)
        );

        caps.has_sse4_2 = (ecx & (1 << 20)) != 0;
        caps.has_avx = (ecx & (1 << 28)) != 0;

        if (max_cpuid >= 7) {
            asm volatile ("cpuid"
                : [eax] "={eax}" (eax),
                  [ebx] "={ebx}" (ebx),
                  [ecx] "={ecx}" (ecx),
                  [edx] "={edx}" (edx)
                : [leaf] "{eax}" (7),
                  [subleaf] "{ecx}" (0)
            );
            caps.has_avx2 = (ebx & (1 << 5)) != 0;
        }
    }

    // Get total memory and page size
    caps.page_size = 4096; // Default page size
    caps.total_memory = detect_total_memory();
    caps.core_count = detect_core_count();

    hw_caps = caps;
    log.info("Hardware capabilities detected: cores={}, memory={}MB", .{
        caps.core_count,
        caps.total_memory / (1024 * 1024),
    });
}

fn detect_total_memory() u64 {
    // This should be replaced with actual memory detection
    // from multiboot information or ACPI tables
    return 16 * 1024 * 1024 * 1024; // 16GB default for now
}

fn detect_core_count() u32 {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx)
        : [leaf] "{eax}" (0x0B)
    );

    return (ebx & 0xFF); // Get logical processor count
}

// Run a single test suite
pub fn run_suite(suite: TestSuite) TestStats {
    var stats = TestStats{};
    const start_time = get_timestamp();

    log.info("Running test suite: {s}", .{suite.name});

    if (suite.setup) |setup| {
        setup();
    }

    for (suite.cases) |test_case| {
        stats.total += 1;

        if (test_case.requires_hardware and !test_config.hardware_check) {
            log.warn("Skipping {s} - hardware check disabled", .{test_case.name});
            stats.skipped += 1;
            continue;
        }

        log.info("Running test: {s}", .{test_case.name});

        var result = TestResult.Error;
        if (test_config.timeout_enabled) {
            result = run_with_timeout(test_case);
        } else {
            result = test_case.func();
        }

        switch (result) {
            .Pass => {
                stats.passed += 1;
                log.info("✓ {s}", .{test_case.name});
            },
            .Fail => {
                stats.failed += 1;
                log.err("✗ {s}", .{test_case.name});
                if (test_config.fail_fast) break;
            },
            .Skip => {
                stats.skipped += 1;
                log.warn("- {s}", .{test_case.name});
            },
            .Error => {
                stats.errors += 1;
                log.err("! {s}", .{test_case.name});
                if (test_config.fail_fast) break;
            },
        }
    }

    if (suite.teardown) |teardown| {
        teardown();
    }

    stats.duration_ms = (get_timestamp() - start_time) / 1_000_000;

    log.info("Suite {s} complete: {}/{} passed ({} skipped, {} errors) in {}ms",
        .{
            suite.name,
            stats.passed,
            stats.total,
            stats.skipped,
            stats.errors,
            stats.duration_ms,
        }
    );

    return stats;
}

// Run a test with timeout
fn run_with_timeout(test_case: TestCase) TestResult {
    var result = TestResult.Error;
    const start_time = get_timestamp();

    result = test_case.func();

    const elapsed = (get_timestamp() - start_time) / 1_000_000;
    if (elapsed > test_case.timeout_ms) {
        log.err("Test {s} timed out after {}ms", .{test_case.name, elapsed});
        return .Error;
    }

    return result;
}

// Get current timestamp in nanoseconds
fn get_timestamp() u64 {
    var timestamp: u64 = undefined;
    asm volatile ("rdtsc"
        : [ret] "={eax}" (timestamp)
    );
    return timestamp;
}

// Test assertion functions
pub fn expect(condition: bool, msg: []const u8) TestResult {
    if (!condition) {
        log.err("Assertion failed: {s}", .{msg});
        return .Fail;
    }
    return .Pass;
}

pub fn expect_equal(actual: anytype, expected: @TypeOf(actual), msg: []const u8) TestResult {
    if (actual != expected) {
        log.err("Assertion failed: {s} (expected {}, got {})", .{msg, expected, actual});
        return .Fail;
    }
    return .Pass;
}

pub fn expect_not_equal(actual: anytype, expected: @TypeOf(actual), msg: []const u8) TestResult {
    if (actual == expected) {
        log.err("Assertion failed: {s} (expected not {})", .{msg, expected});
        return .Fail;
    }
    return .Pass;
}

pub fn expect_error(err: anyerror, expected_err: anyerror, msg: []const u8) TestResult {
    if (err != expected_err) {
        log.err("Assertion failed: {s} (expected error {}, got {})", .{msg, expected_err, err});
        return .Fail;
    }
    return .Pass;
}

// Configuration functions
pub fn set_verbose(verbose: bool) void {
    test_config.verbose = verbose;
}

pub fn set_fail_fast(fail_fast: bool) void {
    test_config.fail_fast = fail_fast;
}

pub fn set_hardware_check(enabled: bool) void {
    test_config.hardware_check = enabled;
}

pub fn set_timeout_enabled(enabled: bool) void {
    test_config.timeout_enabled = enabled;
}

// Get hardware capabilities
pub fn get_hw_caps() HardwareCapabilities {
    return hw_caps;
}
