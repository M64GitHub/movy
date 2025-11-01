const std = @import("std");
const builtin = @import("builtin");
const types = @import("types");

/// Collect system information for reproducible benchmarks
pub fn collect(allocator: std.mem.Allocator) !types.SystemInfo {
    const cpu_model = try getCpuModel(allocator);
    const cpu_cores = try getCpuCores();
    const os_name = getOsName();
    const zig_ver = builtin.zig_version_string;
    const build_mode = getBuildMode();

    return types.SystemInfo{
        .cpu_model = cpu_model,
        .cpu_cores = cpu_cores,
        .os = os_name,
        .zig_version = zig_ver,
        .build_mode = build_mode,
    };
}

fn getCpuModel(allocator: std.mem.Allocator) ![]const u8 {
    const arch = @tagName(builtin.cpu.arch);
    const model = builtin.cpu.model.name;
    return std.fmt.allocPrint(allocator, "{s} ({s})", .{ arch, model });
}

fn getCpuCores() !usize {
    // Try to get logical CPU count
    return std.Thread.getCpuCount() catch 1;
}

fn getOsName() []const u8 {
    return @tagName(builtin.os.tag);
}

fn getBuildMode() []const u8 {
    return switch (builtin.mode) {
        .Debug => "Debug",
        .ReleaseSafe => "ReleaseSafe",
        .ReleaseFast => "ReleaseFast",
        .ReleaseSmall => "ReleaseSmall",
    };
}
