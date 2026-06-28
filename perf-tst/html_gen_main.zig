const std = @import("std");
const html_generator = @import("html_generator");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get base directory from arguments or use default
    const args = &[_][]const u8{"prog"};
    // args are borrowed from argv, no free needed for spans

    const base_dir = if (args.len > 1) args[1] else "perf-results";

    std.debug.print("Generating HTML visualization for: {s}\n", .{base_dir});

    try html_generator.generateHtmlReport(allocator, base_dir);

    std.debug.print("\nDone! Open in browser:\n", .{});
    std.debug.print("  open {s}/index.html\n", .{base_dir});
}
