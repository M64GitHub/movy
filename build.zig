const std = @import("std");

// The following constants are only used for enabled movy_video:
const usr_include_path = "/usr/include/"; // for SDL (audio)
const ffmpeg_include_path = "/usr/include/x86_64-linux-gnu"; // for ffmpeg

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.ReleaseFast;
    // const optimize = b.option(std.builtin.OptimizeMode, "optimize", "") orelse .Debug;

    // -- build options
    // apt-get install libavcodec-dev libavutil-dev libswresample-dev libavformat-dev libswscale-dev
    // const enable_ffmpeg = b.option(bool, "video", "Enable ffmpeg/SDL2 audio support in movy") orelse false;
    // for zls, while editing
    const enable_ffmpeg = false;
    const dummy = b.option(bool, "video", "Enable ffmpeg/SDL2 audio support in movy") orelse false;
    _ = dummy;

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
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
            }),
        });
        example_exe.root_module.addImport("movy", movy_mod); // Link module
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
    };

    for (demos) |name| {
        const demo_exe = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("demos/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        }) });
        demo_exe.root_module.addImport("movy", movy_mod);
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
        const game_exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(b.fmt("games/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        game_exe.root_module.addImport("movy", movy_mod);
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

        // Executables for movy_video
        const names = [_][]const u8{
            "mplayer",
        };

        for (names) |name| {
            const ffmpeg_exe = b.addExecutable(.{
                .name = name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
                    .target = target,
                    .optimize = optimize,
                }),
            });
            ffmpeg_exe.root_module.addImport("movy", movy_mod);
            ffmpeg_exe.root_module.addImport("movy_video", movy_video_mod);
            b.installArtifact(ffmpeg_exe);

            // Add run step
            const run_ffmpeg = b.addRunArtifact(ffmpeg_exe);
            run_ffmpeg.step.dependOn(b.getInstallStep());
            if (b.args) |args| run_ffmpeg.addArgs(args);
            b.step(
                b.fmt("run-{s}", .{name}),
                b.fmt("Run {s}", .{name}),
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
