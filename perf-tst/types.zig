/// Core data types for performance test results
/// Designed for JSON serialization and cross-system comparison

pub const SystemInfo = struct {
    cpu_model: []const u8,
    cpu_cores: usize,
    os: []const u8,
    zig_version: []const u8,
    build_mode: []const u8,
};

pub const MeasurementPoint = struct {
    name: []const u8,
    width: ?usize,
    height: ?usize,
    pixels: usize,
    iterations: usize,
    elapsed_ns: u64,
    time_per_iter_us: f64,
    iter_per_sec: f64,
    megapixels_per_sec: f64,
};

pub const TestResult = struct {
    test_name: []const u8,
    timestamp: []const u8,
    system_info: SystemInfo,
    results: []MeasurementPoint,
};
