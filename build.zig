const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.ReleaseFast;

    // -- movy
    const movy_mod = b.createModule(.{
        .root_source_file = b.path("src/movy.zig"),
        .target = target,
        .optimize = optimize,
    });
    movy_mod.addIncludePath(b.path("src/core/lodepng/"));
    movy_mod.addCSourceFile(.{ .file = b.path("src/core/lodepng/lodepng.c") });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "movy",
        .root_module = movy_mod,
    });
    lib.linkLibC();
    b.installArtifact(lib);

    // -- Examples
    const examples = [_][]const u8{
        "sprite_frame_animation",
        "index_animator_print_idx",
        "keyboard",
        "mouse",
        "keyboard_mouse",
        "sprite_fade",
        "sprite_fade_chain",
        "sprite_fade_chain_pipeline",
        "render_effect_chain",
    };

    for (examples) |name| {
        const example_exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        example_exe.addIncludePath(b.path("src/core/lodepng/"));
        example_exe.root_module.addImport("movy", movy_mod); // Link module
        example_exe.linkLibC();
        b.installArtifact(example_exe);

        // Add run step
        const run_example = b.addRunArtifact(example_exe);
        run_example.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_example.addArgs(args);
        b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run example: {s}", .{name}),
        ).dependOn(&run_example.step);
    }

    // -- Games
    const games = [_][]const u8{
        "boom-zone",
    };

    for (games) |name| {
        const game_exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(b.fmt("games/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        game_exe.addIncludePath(b.path("src/core/lodepng/"));
        game_exe.root_module.addImport("movy", movy_mod); // Link module
        game_exe.linkLibC();
        b.installArtifact(game_exe);

        // Add run step
        const run_game = b.addRunArtifact(game_exe);
        run_game.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_game.addArgs(args);
        b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run {s}", .{name}),
        ).dependOn(&run_game.step);
    }

    // -- Docs
    const docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    b.getInstallStep().dependOn(&docs.step);
}
