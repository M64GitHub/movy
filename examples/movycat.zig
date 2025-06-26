const std = @import("std");
const movy = @import("movy");
const movy_video = @import("movy_video");
const stdout = std.io.getStdOut().writer();

const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libswscale/swscale.h");
    @cInclude("libavutil/imgutils.h");
});

const SDL = @cImport({
    @cInclude("SDL2/SDL.h");
});

const target_width: usize = 160;
const target_height: usize = 90;

const SYNC_WINDOW_NS: i64 = 50_000_000;

const PlayerState = struct {
    paused: bool = false,
    stop: bool = false,

    pause_start_ns: i128 = 0,
    total_paused_ns: i128 = 0,

    pub fn togglePause(
        self: *PlayerState,
        decoder: *movy_video.VideoDecoder,
    ) void {
        self.paused = !self.paused;
        if (decoder.audio) |*a| {
            if (self.paused) {
                // Pause audio and measure pause time
                self.pause_start_ns = a.getAudioClock();
                SDL.SDL_PauseAudioDevice(a.audio_device, 1);
            } else {
                // Continue audio and update clocks for av sync
                const pause_end_ns = a.getAudioClock();
                self.total_paused_ns += pause_end_ns - self.pause_start_ns;

                decoder.video.start_time_ns += pause_end_ns - self.pause_start_ns;
                a.start_time_ns += pause_end_ns - self.pause_start_ns;

                SDL.SDL_PauseAudioDevice(a.audio_device, 0);
            }
        }
    }

    pub fn getEffectiveAudioClock(
        self: *const PlayerState,
        audio: *movy_video.AudioState,
    ) i128 {
        return audio.getAudioClock() - self.total_paused_ns;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        // .verbose_log = true,
    }){};

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // -- Setup movy screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    // try movy.terminal.beginAlternateScreen();
    // defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(
        allocator,
        target_width,
        target_height / 2,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    // -- init render surface for output, and add to screen
    var surface = try movy.RenderSurface.init(
        allocator,
        target_width,
        target_height,
        movy.core.types.Rgb{ .r = 0xff, .g = 0, .b = 0 },
    );
    defer surface.deinit(allocator);

    surface.x = 0;
    surface.y = 0;

    try screen.addRenderSurface(surface);

    // -- Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Error: missing filename\n", .{});
        return error.MissingFileName;
    }

    const file_name = args[1];
    try stdout.print("Working with filename '{s}'\n", .{file_name});

    // Initialize the decoder
    const decoder =
        try movy_video.VideoDecoder.init(allocator, file_name, surface);
    defer decoder.deinit(allocator);

    var reached_end = false;
    var loop_ctr: usize = 0;

    var state = PlayerState{};

    while (!state.stop) {
        loop_ctr += 1;

        // esc input only works with raw terminal mode
        if (try movy.input.get()) |event| {
            if (event == .key and event.key.type == .Escape) {
                state.stop = true;
            }
            // Outta Space
            if (event == .key and event.key.type == .Char and
                event.key.sequence[0] == ' ')
            {
                state.togglePause(decoder);
            }
        }

        if (state.paused) {
            std.time.sleep(10_000_000);
            continue;
        }

        // FIRST: Chck if a frame is ready to render (even before decoding more)
        if (decoder.video.queue_count > 0) {
            if (decoder.video.peekFrame()) |head| {
                const playback_time_ns = decoder.getAudioClock();
                const head_pts_i64 = @as(i64, @intCast(head.pts_ns));
                const audio_i64 = @as(i64, @intCast(playback_time_ns));
                const diff = head_pts_i64 - audio_i64;

                decoder.video.pkt_ctr += 1;

                movy.terminal.cursorHome();
                movy.terminal.cursorDown(@as(i32, @intCast(screen.height() / 2)));
                movy.terminal.setColor(movy.color.WHITE);
                movy.terminal.setBgColor(movy.color.DARK_GRAY);

                if (diff <= SYNC_WINDOW_NS and diff >= -SYNC_WINDOW_NS) {
                    if (decoder.video.popFrameForRender()) |frame_ptr| {
                        decoder.video.frame_ctr += 1;

                        std.debug.print("POPPED  q-size: {}\n", .{decoder.video.queue_count});
                        std.debug.print("POPPED PTS: {}\n", .{frame_ptr.*.pts});
                        std.debug.print("POPPED new tail index: {}\n", .{decoder.video.queue_tail});

                        const t_before = std.time.nanoTimestamp();
                        decoder.video.renderFrameToSurface(frame_ptr, surface);
                        const t_after = std.time.nanoTimestamp();
                        const render_ns = t_after - t_before;

                        if (render_ns > 5_000_000) {
                            std.debug.print("Decoding frame took {} ns\n", .{render_ns});
                            return error.ScalingTooSlow;
                        }

                        screen.render();
                        try screen.output();

                        c.av_frame_free(
                            @as(
                                [*c][*c]c.AVFrame,
                                @constCast(@ptrCast(&frame_ptr)),
                            ),
                        );
                    }
                } else if (diff < -SYNC_WINDOW_NS) {
                    // Video is behind – drop the frame!
                    _ = decoder.video.popFrameForRender();
                } else {
                    // Too early → just wait a bit (add a sleep if you want)
                    std.time.sleep(500_000); // ~0.5ms
                }
            }
        }

        // THEN: Decode only if queue is not full
        if (decoder.video.queue_count < movy_video.MAX_VIDEO_FRAMES) {
            const playback_time_ns = decoder.getAudioClock();
            switch (try decoder.processNextPacket(SYNC_WINDOW_NS, playback_time_ns)) {
                .eof => reached_end = true,
                else => {}, // any outcome advances state
            }
        }

        // all frames processed
        if (decoder.video.queue_count == 0 and reached_end) {
            state.stop = true;
        }

        std.time.sleep(1_000); // bit of breathing space for the cpu
    }

    // The End
}
