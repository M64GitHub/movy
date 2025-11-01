const std = @import("std");
const json_writer = @import("json_writer");
const types = @import("types");

/// Scan perf-results directory and generate HTML visualization
pub fn generateHtmlReport(allocator: std.mem.Allocator, base_dir: []const u8) !void {
    std.debug.print("\n=== Generating HTML Visualization ===\n", .{});

    // Read template
    const template = try std.fs.cwd().readFileAlloc(
        allocator,
        "perf-tst/web-assets/template.html",
        10 * 1024 * 1024, // 10MB max
    );
    defer allocator.free(template);

    // Scan directories and collect run information
    var runs = std.ArrayList(RunInfo){};
    defer {
        for (runs.items) |*run| {
            allocator.free(run.date);
            allocator.free(run.timestamp);
            for (run.files.items) |file| {
                allocator.free(file);
            }
            run.files.deinit(allocator);
            if (run.system_info) |*sys| {
                allocator.free(sys.cpu_model);
                allocator.free(sys.os);
                allocator.free(sys.zig_version);
                allocator.free(sys.build_mode);
            }
        }
        runs.deinit(allocator);
    }

    try scanPerfResults(allocator, base_dir, &runs);

    std.debug.print("Found {d} benchmark runs\n", .{runs.items.len});

    std.debug.print("Generating timestamp...\n", .{});
    // Get current timestamp
    const timestamp = try json_writer.generateTimestamp(allocator);
    defer allocator.free(timestamp);
    std.debug.print("Timestamp: {s}\n", .{timestamp});

    std.debug.print("Starting template replacement...\n", .{});
    // Replace placeholders - track ownership manually
    var html_owned: ?[]const u8 = null;
    defer if (html_owned) |h| allocator.free(h);

    var current_html: []const u8 = template;

    std.debug.print("Replacing TIMESTAMP...\n", .{});
    // {{TIMESTAMP}}
    const html1 = try replaceAll(allocator, current_html, "{{TIMESTAMP}}", timestamp);
    std.debug.print("TIMESTAMP replaced\n", .{});
    if (html1.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html1;
        current_html = html1;
    }

    // {{TOTAL_RUNS}}
    const total_runs_str = try std.fmt.allocPrint(allocator, "{d}", .{runs.items.len});
    defer allocator.free(total_runs_str);
    const html2 = try replaceAll(allocator, current_html, "{{TOTAL_RUNS}}", total_runs_str);
    if (html2.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html2;
        current_html = html2;
    }

    // {{TOTAL_TESTS}}
    var total_tests: usize = 0;
    for (runs.items) |run| {
        total_tests += run.files.items.len;
    }
    const total_tests_str = try std.fmt.allocPrint(allocator, "{d}", .{total_tests});
    defer allocator.free(total_tests_str);
    const html3 = try replaceAll(allocator, current_html, "{{TOTAL_TESTS}}", total_tests_str);
    if (html3.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html3;
        current_html = html3;
    }

    // {{UNIQUE_SYSTEMS}}
    const unique_systems = try countUniqueSystems(allocator, runs.items);
    const unique_systems_str = try std.fmt.allocPrint(allocator, "{d}", .{unique_systems});
    defer allocator.free(unique_systems_str);
    const html4 = try replaceAll(allocator, current_html, "{{UNIQUE_SYSTEMS}}", unique_systems_str);
    if (html4.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html4;
        current_html = html4;
    }

    // {{DATE_RANGE}}
    const date_range = if (runs.items.len > 0) runs.items[runs.items.len - 1].date else "N/A";
    const html5 = try replaceAll(allocator, current_html, "{{DATE_RANGE}}", date_range);
    if (html5.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html5;
        current_html = html5;
    }

    // {{RUN_LIST}}
    const run_list_html = try generateRunListHtml(allocator, runs.items);
    defer allocator.free(run_list_html);
    const html6 = try replaceAll(allocator, current_html, "{{RUN_LIST}}", run_list_html);
    if (html6.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html6;
        current_html = html6;
    }

    // {{RAW_DATA_LINKS}}
    const raw_links_html = try generateRawDataLinksHtml(allocator, runs.items);
    defer allocator.free(raw_links_html);
    const html7 = try replaceAll(allocator, current_html, "{{RAW_DATA_LINKS}}", raw_links_html);
    if (html7.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html7;
        current_html = html7;
    }

    // {{BENCHMARK_DATA_JSON}} - Embed all JSON data
    std.debug.print("Embedding benchmark data JSON...\n", .{});
    const benchmark_json = try generateBenchmarkDataJson(allocator, base_dir, runs.items);
    defer allocator.free(benchmark_json);
    const html8 = try replaceAll(allocator, current_html, "{{BENCHMARK_DATA_JSON}}", benchmark_json);
    if (html8.ptr != current_html.ptr) {
        if (html_owned) |h| allocator.free(h);
        html_owned = html8;
        current_html = html8;
    }

    // Write final HTML
    const output_path = try std.fmt.allocPrint(allocator, "{s}/index.html", .{base_dir});
    defer allocator.free(output_path);

    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    try file.writeAll(current_html);

    // Copy static assets
    try copyAssets(allocator, base_dir);

    std.debug.print("HTML report generated: {s}\n", .{output_path});
    std.debug.print("Open in browser: open {s}\n", .{output_path});
}

const RunInfo = struct {
    date: []const u8,
    timestamp: []const u8,
    files: std.ArrayList([]const u8),
    system_info: ?types.SystemInfo,
};

fn scanPerfResults(allocator: std.mem.Allocator, base_dir: []const u8, runs: *std.ArrayList(RunInfo)) !void {
    var dir = try std.fs.cwd().openDir(base_dir, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;

        // Entry name is the full timestamp directory (e.g., "2025-11-19T14-33-08")
        const timestamp = entry.name;

        // Scan this timestamp directory for JSON files
        var timestamp_dir = try dir.openDir(timestamp, .{ .iterate = true });
        defer timestamp_dir.close();

        var files = std.ArrayList([]const u8){};
        var system_info: ?types.SystemInfo = null;

        var timestamp_it = timestamp_dir.iterate();
        while (try timestamp_it.next()) |file_entry| {
            if (file_entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, file_entry.name, ".json")) continue;

            // Store filename
            const filename_copy = try allocator.dupe(u8, file_entry.name);
            try files.append(allocator, filename_copy);

            // Load first JSON to get system info
            if (system_info == null) {
                const json_path = try std.fmt.allocPrint(
                    allocator,
                    "{s}/{s}/{s}",
                    .{ base_dir, timestamp, file_entry.name },
                );
                defer allocator.free(json_path);

                system_info = try loadSystemInfo(allocator, json_path);
            }
        }

        if (files.items.len > 0) {
            // Extract date from timestamp (first 10 chars: YYYY-MM-DD)
            const date = if (timestamp.len >= 10) timestamp[0..10] else timestamp;

            try runs.append(allocator, RunInfo{
                .date = try allocator.dupe(u8, date),
                .timestamp = try allocator.dupe(u8, timestamp),
                .files = files,
                .system_info = system_info,
            });
        } else {
            // Clean up if we didn't add the run
            for (files.items) |file| {
                allocator.free(file);
            }
            files.deinit(allocator);
        }
    }
}

fn extractTimestampFromFilename(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    // Example: "RenderSurface.toAnsi_2025-11-19T13-20-02.json"
    // Extract: "2025-11-19T13-20-02"

    const underscore_idx = std.mem.lastIndexOf(u8, filename, "_") orelse return error.InvalidFilename;
    const dot_idx = std.mem.lastIndexOf(u8, filename, ".") orelse return error.InvalidFilename;

    if (underscore_idx >= dot_idx) return error.InvalidFilename;

    const timestamp = filename[underscore_idx + 1 .. dot_idx];
    return try allocator.dupe(u8, timestamp);
}

fn loadSystemInfo(allocator: std.mem.Allocator, json_path: []const u8) !types.SystemInfo {
    const content = try std.fs.cwd().readFileAlloc(allocator, json_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(types.TestResult, allocator, content, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    return types.SystemInfo{
        .cpu_model = try allocator.dupe(u8, parsed.value.system_info.cpu_model),
        .cpu_cores = parsed.value.system_info.cpu_cores,
        .os = try allocator.dupe(u8, parsed.value.system_info.os),
        .zig_version = try allocator.dupe(u8, parsed.value.system_info.zig_version),
        .build_mode = try allocator.dupe(u8, parsed.value.system_info.build_mode),
    };
}

fn generateRunListHtml(allocator: std.mem.Allocator, runs: []const RunInfo) ![]const u8 {
    var html = std.ArrayList(u8){};
    defer html.deinit(allocator);

    for (runs) |run| {
        std.debug.print("Generating row for run: {s}/{s}\n", .{ run.date, run.timestamp });

        // Build files JSON string - simpler approach using direct allocation
        var files_json_len: usize = 2; // "[]"
        for (run.files.items) |file| {
            files_json_len += file.len + 3; // file + quotes + comma
        }

        const files_json = try allocator.alloc(u8, files_json_len);
        defer allocator.free(files_json);

        var pos: usize = 0;
        files_json[pos] = '[';
        pos += 1;

        for (run.files.items, 0..) |file, i| {
            if (i > 0) {
                files_json[pos] = ',';
                pos += 1;
            }
            files_json[pos] = '"';
            pos += 1;
            @memcpy(files_json[pos .. pos + file.len], file);
            pos += file.len;
            files_json[pos] = '"';
            pos += 1;
        }

        files_json[pos] = ']';
        pos += 1;

        const actual_files_json = files_json[0..pos];

        const cpu_model = if (run.system_info) |si| si.cpu_model else "Unknown";
        const cpu_cores = if (run.system_info) |si| si.cpu_cores else 0;
        const os = if (run.system_info) |si| si.os else "Unknown";

        std.debug.print("About to write HTML row...\n", .{});
        std.debug.print("Files JSON: {s}\n", .{actual_files_json});
        std.debug.print("date: {s}, timestamp: {s}, cpu: {s}, os: {s}, cores: {d}\n",
            .{ run.date, run.timestamp, cpu_model, os, cpu_cores });

        // Test simple allocPrint first
        std.debug.print("Testing allocPrint...\n", .{});
        const test_str = try std.fmt.allocPrint(allocator, "test-{s}", .{run.date});
        std.debug.print("allocPrint works: {s}\n", .{test_str});
        allocator.free(test_str);

        // Build row using allocPrint with shorter segments to avoid issues
        std.debug.print("Building row_part1...\n", .{});
        const row_part1 = try std.fmt.allocPrint(allocator,
            "<tr data-date=\"{s}\" data-timestamp=\"{s}\" data-files='{s}'>\n",
            .{ run.date, run.timestamp, actual_files_json }
        );
        std.debug.print("row_part1 created\n", .{});
        try html.appendSlice(allocator, row_part1);
        allocator.free(row_part1);

        const row_part2 = try std.fmt.allocPrint(allocator,
            "  <td>{s}</td>\n  <td class=\"timestamp\">{s}</td>\n  <td>{s}</td>\n",
            .{ run.date, run.timestamp, cpu_model }
        );
        try html.appendSlice(allocator, row_part2);
        allocator.free(row_part2);

        const row_part3 = try std.fmt.allocPrint(allocator,
            "  <td><span class=\"badge badge-cpu\">{s}</span></td>\n  <td>{d}</td>\n",
            .{ cpu_model, cpu_cores }
        );
        try html.appendSlice(allocator, row_part3);
        allocator.free(row_part3);

        const row_part4 = try std.fmt.allocPrint(allocator,
            "  <td><span class=\"badge badge-os\">{s}</span></td>\n  <td>{d}</td>\n",
            .{ os, run.files.items.len }
        );
        try html.appendSlice(allocator, row_part4);
        allocator.free(row_part4);

        const row_part5 = "  <td><button class=\"btn btn-expand\">View Charts</button></td>\n</tr>\n";
        try html.appendSlice(allocator, row_part5);

        std.debug.print("Row written successfully\n", .{});
    }

    std.debug.print("Run list HTML generated\n", .{});
    return try html.toOwnedSlice(allocator);
}

fn generateBenchmarkDataJson(allocator: std.mem.Allocator, base_dir: []const u8, runs: []const RunInfo) ![]const u8 {
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);

    try result.appendSlice(allocator, "{\n");

    for (runs, 0..) |run, run_idx| {
        const run_key = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ run.date, run.timestamp });
        defer allocator.free(run_key);

        try result.appendSlice(allocator, "  \"");
        try result.appendSlice(allocator, run_key);
        try result.appendSlice(allocator, "\": {\n");

        for (run.files.items, 0..) |file, file_idx| {
            // Read the JSON file
            const json_path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ base_dir, run.timestamp, file });
            defer allocator.free(json_path);

            const json_content = try std.fs.cwd().readFileAlloc(allocator, json_path, 10 * 1024 * 1024);
            defer allocator.free(json_content);

            // Parse to get test name
            const parsed = try std.json.parseFromSlice(types.TestResult, allocator, json_content, .{
                .allocate = .alloc_always,
            });
            defer parsed.deinit();

            const test_name = parsed.value.test_name;

            try result.appendSlice(allocator, "    \"");
            try result.appendSlice(allocator, test_name);
            try result.appendSlice(allocator, "\": ");
            try result.appendSlice(allocator, json_content);

            if (file_idx < run.files.items.len - 1) {
                try result.appendSlice(allocator, ",\n");
            } else {
                try result.appendSlice(allocator, "\n");
            }
        }

        try result.appendSlice(allocator, "  }");

        if (run_idx < runs.len - 1) {
            try result.appendSlice(allocator, ",\n");
        } else {
            try result.appendSlice(allocator, "\n");
        }
    }

    try result.appendSlice(allocator, "}");

    return try result.toOwnedSlice(allocator);
}

fn generateRawDataLinksHtml(allocator: std.mem.Allocator, runs: []const RunInfo) ![]const u8 {
    var html = std.ArrayList(u8){};
    defer html.deinit(allocator);

    for (runs) |run| {
        try html.appendSlice(allocator, "<div class=\"raw-data-run\">\n");

        const header = try std.fmt.allocPrint(allocator, "  <h3 class=\"text-cyan\">{s}</h3>\n  <div>\n", .{run.timestamp});
        try html.appendSlice(allocator, header);
        allocator.free(header);

        for (run.files.items) |file| {
            const link = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ run.timestamp, file });
            defer allocator.free(link);

            const item = try std.fmt.allocPrint(allocator,
                "    <a href=\"{s}\" class=\"btn\" target=\"_blank\">{s}</a>\n",
                .{ link, file });
            try html.appendSlice(allocator, item);
            allocator.free(item);
        }

        try html.appendSlice(allocator, "  </div>\n</div>\n");
    }

    return try html.toOwnedSlice(allocator);
}

fn countUniqueSystems(allocator: std.mem.Allocator, runs: []const RunInfo) !usize {
    var seen = std.StringHashMap(void).init(allocator);
    defer {
        var it = seen.keyIterator();
        while (it.next()) |key| {
            allocator.free(key.*);
        }
        seen.deinit();
    }

    for (runs) |run| {
        if (run.system_info) |si| {
            const key = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ si.cpu_model, si.cpu_cores });

            // Check if key already exists
            if (seen.contains(key)) {
                allocator.free(key); // Free duplicate
            } else {
                try seen.put(key, {}); // HashMap takes ownership
            }
        }
    }

    return seen.count();
}

fn copyAssets(allocator: std.mem.Allocator, base_dir: []const u8) !void {
    const assets = [_][]const u8{ "style.css", "visualizer.js" };

    for (assets) |asset| {
        const src_path = try std.fmt.allocPrint(allocator, "perf-tst/web-assets/{s}", .{asset});
        defer allocator.free(src_path);

        const dst_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_dir, asset });
        defer allocator.free(dst_path);

        try std.fs.cwd().copyFile(src_path, std.fs.cwd(), dst_path, .{});
        std.debug.print("Copied: {s} -> {s}\n", .{ src_path, dst_path });
    }

    // Copy logo
    const logo_src = "perf-tst/assets/movy-logo.png";
    const logo_dst = try std.fmt.allocPrint(allocator, "{s}/movy-logo.png", .{base_dir});
    defer allocator.free(logo_dst);

    try std.fs.cwd().copyFile(logo_src, std.fs.cwd(), logo_dst, .{});
    std.debug.print("Copied: {s} -> {s}\n", .{ logo_src, logo_dst });
}

fn replaceAll(allocator: std.mem.Allocator, haystack: []const u8, needle: []const u8, replacement: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        return try allocator.dupe(u8, haystack);
    }

    var result = std.ArrayList(u8){};
    const writer = result.writer(allocator);

    var remaining = haystack;
    while (std.mem.indexOf(u8, remaining, needle)) |idx| {
        try writer.writeAll(remaining[0..idx]);
        try writer.writeAll(replacement);
        remaining = remaining[idx + needle.len ..];
    }

    try writer.writeAll(remaining);
    return try result.toOwnedSlice(allocator);
}
