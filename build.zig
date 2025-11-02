const std = @import("std");

// The following constants are only used for enabled movy_video:
const usr_include_path = "/usr/include/"; // for SDL (audio)
const ffmpeg_include_path = "/usr/include/x86_64-linux-gnu"; // for ffmpeg

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.ReleaseFast;

    // -- build options
    // apt-get install libavcodec-dev libavutil-dev libswresample-dev libavformat-dev libswscale-dev
    const enable_ffmpeg = b.option(
        bool,
        "video",
        "Enable ffmpeg/SDL2 audio support in movy",
    ) orelse false;

    // -- movy
    const movy_mod = b.addModule("movy", .{
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

    // -- Tests
    // Create test artifact using the movy module
    const lib_unit_tests = b.addTest(.{
        .root_module = movy_mod,
    });
    lib_unit_tests.linkLibC();

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // -- Legacy Examples (moved to examples/legacy/)
    const legacy_examples = [_][]const u8{
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

    for (legacy_examples) |name| {
        // Create module for legacy example
        const example_mod = b.addModule(b.fmt("legacy_example_{s}", .{name}), .{
            .root_source_file = b.path(b.fmt("examples/legacy/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        example_mod.addImport("movy", movy_mod);

        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = example_mod,
        });
        b.installArtifact(example_exe);

        // Add run step
        const run_example = b.addRunArtifact(example_exe);
        run_example.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_example.addArgs(args);
        b.step(
            b.fmt("run-legacy-{s}", .{name}),
            b.fmt("Run legacy example: {s}", .{name}),
        ).dependOn(&run_example.step);
    }

    // -- Examples
    const examples = [_][]const u8{
        "basic_surface",
        "alpha_blending",
        "layered_scene",
        "png_loader",
        "sprite_alpha_rendering",
    };

    for (examples) |name| {
        // Create module for example
        const example_mod = b.addModule(b.fmt("example_{s}", .{name}), .{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        example_mod.addImport("movy", movy_mod);

        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = example_mod,
        });
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

    // -- Demos
    const demos = [_][]const u8{
        "mouse_demo",
        "win_demo",
        "simple_game",
        "stars",
        "blender_demo",
    };

    for (demos) |name| {
        // Create module for demo
        const demo_mod = b.addModule(b.fmt("demo_{s}", .{name}), .{
            .root_source_file = b.path(b.fmt("demos/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        demo_mod.addImport("movy", movy_mod);

        const demo_exe = b.addExecutable(.{
            .name = name,
            .root_module = demo_mod,
        });
        b.installArtifact(demo_exe);

        // Add run step
        const run_demo = b.addRunArtifact(demo_exe);
        run_demo.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_demo.addArgs(args);
        b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run {s}", .{name}),
        ).dependOn(&run_demo.step);
    }

    // -- Games
    const games = [_][]const u8{};

    for (games) |name| {
        // Create module for game
        const game_mod = b.addModule(b.fmt("game_{s}", .{name}), .{
            .root_source_file = b.path(b.fmt("games/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        game_mod.addImport("movy", movy_mod);

        const game_exe = b.addExecutable(.{
            .name = name,
            .root_module = game_mod,
        });
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

    // -- Performance Tests
    // Get flagZ dependency
    const flagz_dep = b.dependency("flagz", .{
        .target = target,
        .optimize = optimize,
    });
    const flagz_mod = flagz_dep.module("flagz");

    // Perf test shared modules
    const perf_common_mod = b.addModule("common", .{
        .root_source_file = b.path("perf-tst/common.zig"),
        .target = target,
        .optimize = optimize,
    });

    const perf_types_mod = b.addModule("types", .{
        .root_source_file = b.path("perf-tst/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    const perf_system_info_mod = b.addModule("system_info", .{
        .root_source_file = b.path("perf-tst/system_info.zig"),
        .target = target,
        .optimize = optimize,
    });
    perf_system_info_mod.addImport("types", perf_types_mod);

    const perf_json_writer_mod = b.addModule("json_writer", .{
        .root_source_file = b.path("perf-tst/json_writer.zig"),
        .target = target,
        .optimize = optimize,
    });
    perf_json_writer_mod.addImport("types", perf_types_mod);

    const perf_html_generator_mod = b.addModule("html_generator", .{
        .root_source_file = b.path("perf-tst/html_generator.zig"),
        .target = target,
        .optimize = optimize,
    });
    perf_html_generator_mod.addImport("types", perf_types_mod);
    perf_html_generator_mod.addImport("json_writer", perf_json_writer_mod);

    const perf_tests = [_][]const u8{
        "RenderEngine.render",
        "RenderSurface.toAnsi",
        "RenderEngine.render_with_toAnsi",
        "RenderEngine.render_stable",
        "RenderEngine.render_stable_with_toAnsi",
    };

    for (perf_tests) |name| {
        // Create module for perf test
        const perf_mod = b.addModule(b.fmt("perf_{s}", .{name}), .{
            .root_source_file = b.path(b.fmt("perf-tst/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        perf_mod.addImport("movy", movy_mod);
        perf_mod.addImport("common", perf_common_mod);
        perf_mod.addImport("flagz", flagz_mod);
        perf_mod.addImport("types", perf_types_mod);
        perf_mod.addImport("system_info", perf_system_info_mod);
        perf_mod.addImport("json_writer", perf_json_writer_mod);

        const perf_exe = b.addExecutable(.{
            .name = b.fmt("perf-{s}", .{name}),
            .root_module = perf_mod,
        });
        b.installArtifact(perf_exe);

        // Add run step
        const run_perf = b.addRunArtifact(perf_exe);
        run_perf.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_perf.addArgs(args);
        b.step(
            b.fmt("perf-{s}", .{name}),
            b.fmt("Run performance test: {s}", .{name}),
        ).dependOn(&run_perf.step);
    }

    // -- Performance Test Runner
    const runner_mod = b.addModule("perf_runner", .{
        .root_source_file = b.path("perf-tst/runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    runner_mod.addImport("flagz", flagz_mod);
    runner_mod.addImport("json_writer", perf_json_writer_mod);
    runner_mod.addImport("html_generator", perf_html_generator_mod);

    const runner_exe = b.addExecutable(.{
        .name = "perf-runner",
        .root_module = runner_mod,
    });
    b.installArtifact(runner_exe);

    const run_runner = b.addRunArtifact(runner_exe);
    run_runner.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_runner.addArgs(args);
    b.step(
        "perf-runner",
        "Run all performance tests and generate HTML visualization",
    ).dependOn(&run_runner.step);

    // -- Standalone HTML Generator
    const html_gen_main_mod = b.addModule("html_gen_main", .{
        .root_source_file = b.path("perf-tst/html_gen_main.zig"),
        .target = target,
        .optimize = optimize,
    });
    html_gen_main_mod.addImport("html_generator", perf_html_generator_mod);

    const html_gen_exe = b.addExecutable(.{
        .name = "perf-html-gen",
        .root_module = html_gen_main_mod,
    });
    b.installArtifact(html_gen_exe);

    const run_html_gen = b.addRunArtifact(html_gen_exe);
    run_html_gen.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_html_gen.addArgs(args);
    b.step(
        "perf-html-gen",
        "Generate HTML visualization from existing JSON results",
    ).dependOn(&run_html_gen.step);

    if (enable_ffmpeg) {
        const movy_video_mod = b.addModule("movy_video", .{
            .root_source_file = b.path("src/video/video.zig"),
            .target = target,
            .optimize = optimize,
        });

        movy_video_mod.addIncludePath(.{ .cwd_relative = ffmpeg_include_path });
        movy_video_mod.addImport("movy", movy_mod);
        // link ffmpeg
        movy_video_mod.linkSystemLibrary("avformat", .{});
        movy_video_mod.linkSystemLibrary("avcodec", .{});
        movy_video_mod.linkSystemLibrary("swscale", .{});
        movy_video_mod.linkSystemLibrary("avutil", .{});
        movy_video_mod.linkSystemLibrary("swresample", .{}); // audio
        // link SDL2
        movy_video_mod.linkSystemLibrary("SDL2", .{});

        // Executables for movy_video (in demos/)
        const names = [_][]const u8{
            "mplayer",
        };

        for (names) |name| {
            // Create module for ffmpeg demo
            const ffmpeg_mod = b.addModule(b.fmt("ffmpeg_{s}", .{name}), .{
                .root_source_file = b.path(b.fmt("demos/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
            });
            ffmpeg_mod.addImport("movy", movy_mod);
            ffmpeg_mod.addImport("movy_video", movy_video_mod);

            const ffmpeg_exe = b.addExecutable(.{
                .name = name,
                .root_module = ffmpeg_mod,
            });
            b.installArtifact(ffmpeg_exe);

            // Add run step
            const run_ffmpeg = b.addRunArtifact(ffmpeg_exe);
            run_ffmpeg.step.dependOn(b.getInstallStep());
            if (b.args) |args| run_ffmpeg.addArgs(args);
            b.step(
                b.fmt("run-demo-{s}", .{name}),
                b.fmt("Run demo: {s}", .{name}),
            ).dependOn(&run_ffmpeg.step);
        }
    }

    // -- Docs
    const docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    b.getInstallStep().dependOn(&docs.step);
}
