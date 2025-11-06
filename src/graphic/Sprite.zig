const std = @import("std");
const movy = @import("../movy.zig");

const SpriteError = Sprite.SpriteError;

/// A single frame of a sprite containing both source data and output buffers.
/// Each frame has two RenderSurfaces: data_surface (immutable source pixels)
/// and output_surface (working buffer for effects and rendering).
pub const SpriteFrame = struct {
    x_rel: i32 = 0,
    y_rel: i32 = 0,
    w: usize = 0,
    h: usize = 0,
    data_surface: *movy.core.RenderSurface,
    output_surface: *movy.core.RenderSurface,

    /// Initializes a SpriteFrame with given width and height
    pub fn init(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !*SpriteFrame {
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const data_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(data_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = w,
            .h = h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }

    /// Deinitializes a SpriteFrame, freeing all its allocated resources
    pub fn deinit(self: *SpriteFrame, allocator: std.mem.Allocator) void {
        self.data_surface.deinit(allocator);
        self.output_surface.deinit(allocator);
        allocator.destroy(self);
    }

    /// Initializes a SpriteFrame from a .png file
    pub fn initFromPng(
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        const data_surface =
            try movy.core.RenderSurface.createFromPng(allocator, file_path);
        errdefer allocator.destroy(data_surface);

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            data_surface.w,
            data_surface.h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        try output_surface.copy(data_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = data_surface.w,
            .h = data_surface.h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }

    /// Creates a new SpriteFrame from an ANSI string
    pub fn initFromAnsiStr(
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
    ) !*SpriteFrame {
        const data_surface =
            try movy.core.RenderSurface.createFromAnsi(allocator, img_str);
        errdefer allocator.destroy(data_surface);

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            data_surface.w,
            data_surface.h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = data_surface.w,
            .h = data_surface.h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }
};

/// Collection of animation frames with a current frame index.
/// Manages the lifecycle of multiple SpriteFrame instances and tracks
/// which frame is currently active for display.
pub const SpriteFrameSet = struct {
    frames: std.ArrayList(*SpriteFrame),
    frame_idx: usize = 0,

    /// Initializes a SpriteFrameSet with a given number of frames,
    /// all with w and h
    pub fn init(
        allocator: std.mem.Allocator,
        frame_count: usize,
        w: usize,
        h: usize,
    ) !SpriteFrameSet {
        var frames = std.ArrayList(*SpriteFrame){};
        errdefer frames.deinit(allocator);

        try frames.ensureTotalCapacity(allocator, frame_count); // Pre-allocate space
        for (0..frame_count) |_| {
            const frame = try SpriteFrame.init(allocator, w, h);
            try frames.append(allocator, frame);
        }

        return SpriteFrameSet{
            .frames = frames,
            .frame_idx = 0,
        };
    }

    /// Deinitializes a SpriteFrameSet, freeing all frames and the list
    pub fn deinit(self: *SpriteFrameSet, allocator: std.mem.Allocator) void {
        for (self.frames.items) |frame| {
            frame.deinit(allocator);
        }
        self.frames.deinit(allocator);
    }

    /// Adds a new SpriteFrame with given width and height to the frameset
    pub fn addSpriteFrame(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        const new_frame = try SpriteFrame.init(allocator, w, h);
        try self.frames.append(allocator, new_frame);
    }

    /// Adds a new SpriteFrame from a .png file, and returns a pointer to it
    pub fn addFrameFromPng(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        const new_frame = try SpriteFrame.initFromPng(allocator, file_path);
        try self.frames.append(allocator, new_frame);
        return new_frame;
    }

    /// Adds a new SpriteFrame from an ANSI string to the frameset
    pub fn addFrameFromAnsiStr(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
    ) !*SpriteFrame {
        const new_frame = try SpriteFrame.initFromAnsiStr(allocator, img_str);
        try self.frames.append(allocator, new_frame);
        return new_frame;
    }
};

/// Animated sprite with frame management, named animations, and effect support.
/// Combines multiple frames into a cohesive entity with position (x,y),
/// z-index, and pluggable render effects via RenderEffectContext.
pub const Sprite = struct {
    name: []u8 = &[_]u8{},
    w: usize = 0,
    h: usize = 0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    frame_set: SpriteFrameSet,
    animations: std.StringHashMap(FrameAnimation),
    active_animation: ?[]const u8 = null,
    output_surface: *movy.core.RenderSurface,
    effect_ctx: movy.render.Effect.RenderEffectContext,

    pub const SpriteError = error{
        AnimationNotFound,
        // ...
    };

    /// Error set for frame surface functions
    pub const FrameError = error{
        EmptyFrameSet, // No frames in the set
        InvalidFrameIndex, // Index out of bounds
    };

    /// Named animation sequence with speed control and loop mode.
    /// Wraps an IndexAnimator to control frame progression through
    /// a sprite's frame set.
    pub const FrameAnimation = struct {
        animator: movy.animation.IndexAnimator,
        just_started: bool = true,
        speed: usize = 1,
        speed_ctr: usize = 0,

        /// Creates a new FrameAnimation with the given frame range,
        /// loop mode, and playback speed (frames to wait between updates).
        pub fn init(
            start: usize,
            end: usize,
            mode: movy.animation.IndexAnimator.LoopMode,
            speed: usize,
        ) FrameAnimation {
            return .{
                .animator = movy.animation.IndexAnimator.init(
                    start,
                    end,
                    mode,
                ),
                .speed = speed,
                .speed_ctr = speed,
            };
        }

        /// Advances the animation and updates the sprite's frame index
        pub fn step(self: *FrameAnimation, sprite: *Sprite) void {
            if (self.speed_ctr > 0) {
                // wait
                self.speed_ctr -= 1;
            } else {
                self.speed_ctr = self.speed;
                if (self.just_started) {
                    self.just_started = false;
                    return;
                }
                const index = self.animator.step();
                sprite.frame_set.frame_idx = index;
            }
        }

        /// Returns true if this animation has completed (only for .once mode).
        pub fn finished(self: *FrameAnimation) bool {
            return self.animator.once_finished;
        }
    };

    /// Initializes a Sprite with a single frame of given width and height
    pub fn init(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        name: []const u8,
    ) !*Sprite {
        const frame_set = try SpriteFrameSet.init(allocator, 1, w, h);
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);
        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = frame_set.frames.items[0].data_surface,
            .output_surface = output_surface,
        };

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sprite = try allocator.create(Sprite);

        sprite.* = Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };

        return sprite;
    }

    /// Deinitializes a Sprite, freeing all its allocated resources
    pub fn deinit(self: *Sprite, allocator: std.mem.Allocator) void {
        self.frame_set.deinit(allocator);
        self.output_surface.deinit(allocator);
        if (self.name.len > 0) allocator.free(self.name);
        self.animations.deinit();
        allocator.destroy(self);
    }

    /// Sets the current active frame by index.
    ///
    /// This updates both the visible frame index and the input surface used by
    /// the sprite’s internal RenderEffectContext, ensuring effects target the
    /// correct frame data when rendering.
    ///
    /// Returns an error if the index is out of bounds.
    pub fn setFrameIndex(self: *Sprite, idx: usize) !void {
        if (idx > self.frame_set.frames.items.len - 1) {
            return error.InvalidFrameIndex;
        }
        self.frame_set.frame_idx = idx;
        self.effect_ctx.input_surface = try self.getCurrentFrameSurface();
    }

    /// Returns the data_surface of the current frame based on frame_idx
    pub fn getCurrentFrameSurface(
        self: *Sprite,
    ) FrameError!*movy.core.RenderSurface {
        if (self.frame_set.frames.items.len == 0) {
            return error.EmptyFrameSet;
        }
        const idx = self.frame_set.frame_idx;
        return self.frame_set.frames.items[idx].data_surface;
    }

    /// Returns the data_surface of the SpriteFrame at the given index
    pub fn getFrameSurface(
        self: *Sprite,
        index: usize,
    ) FrameError!*movy.core.RenderSurface {
        if (self.frame_set.frames.items.len == 0) {
            return error.EmptyFrameSet;
        }
        if (index >= self.frame_set.frames.items.len) {
            return error.InvalidFrameIndex;
        }
        return self.frame_set.frames.items[index].data_surface;
    }

    /// Adds new frames to the sprite with given width and height,
    /// returns pointer to the first new frame
    pub fn addFrames(
        self: *Sprite,
        allocator: std.mem.Allocator,
        n: usize,
        width: usize,
        height: usize,
    ) !*SpriteFrame {
        const start_idx = self.frame_set.frames.items.len;
        try self.frame_set.frames.ensureTotalCapacity(allocator, start_idx + n);

        for (0..n) |_| {
            const new_frame = try SpriteFrame.init(allocator, width, height);
            try self.frame_set.frames.append(allocator, new_frame);
        }

        return self.frame_set.frames.items[start_idx]; // First new frame
    }

    /// Adds a new frame to the sprite loaded from a PNG file,
    /// returns pointer to the new frame
    pub fn addFrameFromPng(
        self: *Sprite,
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        return try self.frame_set.addFrameFromPng(allocator, file_path);
    }

    /// Adds a named animation to the sprite's animation map.
    /// This simplifies external usage by handling allocation and insertion
    /// internally.
    ///
    /// Example:
    /// ```zig
    /// try sprite.addAnimation(allocator, "up",
    ///     try FrameAnimation.init("up", 0, 3, .loop));
    /// ```
    pub fn addAnimation(
        self: *Sprite,
        allocator: std.mem.Allocator,
        name: []const u8,
        anim: FrameAnimation,
    ) !void {
        const myname = try allocator.dupe(u8, name);
        try self.animations.put(myname, anim);
    }

    /// Sets the currently active animation by name. If the animation does not
    /// exist, returns `SpriteError.AnimationNotFound`.
    ///
    /// After calling this, the sprite will update its frame each time
    /// `stepActiveAnimation()` is called.
    pub fn startAnimation(
        self: *Sprite,
        name: []const u8,
    ) Sprite.SpriteError!void {
        if (!self.animations.contains(name)) {
            std.debug.print(
                "Animation not found: '{s}'\nAvailable animations:\n",
                .{name},
            );

            var it = self.animations.iterator();
            while (it.next()) |entry| {
                std.debug.print("- {s}\n", .{entry.key_ptr.*});
            }

            return Sprite.SpriteError.AnimationNotFound;
        }

        self.active_animation = name;

        if (self.animations.getPtr(name)) |anim_ptr| {
            anim_ptr.animator.current = anim_ptr.animator.start;
            anim_ptr.animator.once_finished = false;
            anim_ptr.just_started = true;
            anim_ptr.speed_ctr = anim_ptr.speed;
            self.frame_set.frame_idx = anim_ptr.animator.start;
        }
    }

    /// Advances the currently active animation, if one is set, and updates the
    /// sprite's current frame index accordingly.
    ///
    /// This should be called once per frame update to animate the sprite.
    /// It is safe to call even when no active animation is set.
    pub fn stepActiveAnimation(self: *Sprite) void {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                anim_ptr.step(self);
            }
        }
    }

    /// Resets the active animation to its initial frame index,
    /// if any is active.
    /// Useful when restarting an animation manually.
    pub fn resetActiveAnimation(self: *Sprite) void {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                anim_ptr.animator.current = anim_ptr.animator.start;
                anim_ptr.step(self);
            }
        }
    }

    /// Returns true if the active animation has finished
    /// (only meaningful for .once loop mode).
    pub fn finishedActiveAnimation(self: *Sprite) bool {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                return anim_ptr.finished();
            }
        }
        return false;
    }

    /// Initializes a Sprite with a single frame loaded from a PNG file
    pub fn initFromPng(
        allocator: std.mem.Allocator,
        file_path: []const u8,
        name: []const u8,
    ) !*Sprite {
        var frame_set = SpriteFrameSet{
            .frames = std.ArrayList(*SpriteFrame){},
        };
        try frame_set.frames.ensureTotalCapacity(allocator, 4);
        errdefer frame_set.deinit(allocator);

        // Add the first frame from PNG directly to frame_set
        const frame = try frame_set.addFrameFromPng(allocator, file_path);
        const w = frame.w;
        const h = frame.h;

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const data_surface =
            frame_set.frames.items[0].data_surface;

        try output_surface.copy(data_surface);

        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = data_surface,
            .output_surface = output_surface,
        };

        const sprite = try allocator.create(Sprite);
        sprite.* = Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };

        return sprite;
    }

    /// Initializes a Sprite with a single frame loaded from an ANSI string
    pub fn initFromAnsiStr(
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
        name: []const u8,
    ) !Sprite {
        var frame_set = SpriteFrameSet{
            .frames = std.ArrayList(*SpriteFrame){},
        };
        try frame_set.frames.ensureTotalCapacity(allocator, 4);
        errdefer frame_set.deinit(allocator);

        const frame = try frame_set.addFrameFromAnsiStr(allocator, img_str);
        const w = frame.w;
        const h = frame.h;

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        try output_surface.copy(frame.data_surface);

        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = frame_set.frames.items[0].data_surface,
            .output_surface = output_surface,
        };

        return Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };
    }

    /// Copies the current frame's data_surface to the sprite's output_surface.
    pub fn applyCurrentFrame(self: *Sprite) !void {
        try self.output_surface.copy(try self.getCurrentFrameSurface());
    }

    /// Sets the alpha (opacity) for the current frame's surface.
    /// Alpha values range from 0 (fully transparent) to 255 (fully opaque).
    pub fn setAlphaCurrentFrameSurface(self: *Sprite, alpha: u8) !void {
        const surface = try self.getCurrentFrameSurface();
        surface.setAlpha(alpha);
    }

    /// Renders the current frame's data_surface to an ANSI string
    pub fn toAnsi(self: *Sprite) ![]u8 {
        const current_frame =
            self.frame_set.frames.items[self.frame_set.frame_idx];
        return try current_frame.data_surface.toAnsi();
    }

    /// Sets sprite position
    pub fn setXY(self: *Sprite, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
        self.output_surface.x = x;
        self.output_surface.y = y;
        const data_surface: ?*movy.core.RenderSurface =
            self.getCurrentFrameSurface() catch null;
        if (data_surface) |surface| {
            surface.x = x;
            surface.y = y;
        }
    }

    /// Splits the first frame's data_surface horizontally into equal-width
    /// frames, copying each region manually by slicing the color_map,
    /// shadow_map, and char_map.
    pub fn splitByWidth(
        self: *Sprite,
        allocator: std.mem.Allocator,
        split_width: usize,
    ) !void {
        const full_frame = self.frame_set.frames.items[0];
        const src = full_frame.data_surface;
        const h = src.h;
        const w = src.w;

        if (w == 0 or h == 0 or split_width == 0 or w % split_width != 0) {
            return error.InvalidDimensions;
        }

        const num_frames = w / split_width;

        for (0..num_frames) |i| {
            const new_frame = try SpriteFrame.init(allocator, split_width, h);
            try self.frame_set.frames.append(allocator, new_frame);
            const dst = new_frame.data_surface;

            for (0..h) |y| {
                const src_row_start = y * w + (i * split_width);
                const dst_row_start = y * split_width;

                // Copy RGB
                @memcpy(
                    dst.color_map[dst_row_start .. dst_row_start + split_width],
                    src.color_map[src_row_start .. src_row_start + split_width],
                );

                // Copy shadow map
                @memcpy(
                    dst.shadow_map[dst_row_start .. dst_row_start + split_width],
                    src.shadow_map[src_row_start .. src_row_start + split_width],
                );

                // Copy char map
                @memcpy(
                    dst.char_map[dst_row_start .. dst_row_start + split_width],
                    src.char_map[src_row_start .. src_row_start + split_width],
                );
            }

            // Copy to output surface for display
            try new_frame.output_surface.copy(dst);
        }

        self.frame_set.frame_idx = 1;
        self.w = split_width;

        // Optional not sure yet: remove the original full-sized frame
        // full_frame.deinit(allocator);
        // _ = self.frame_set.frames.orderedRemove(0);
    }

    /// Splits the first frame's data_surface vertically into equal-height
    /// frames, copying each region manually by slicing the color_map,
    /// shadow_map, and char_map.
    pub fn splitByHeight(
        self: *Sprite,
        allocator: std.mem.Allocator,
        split_height: usize,
    ) !void {
        const full_frame = self.frame_set.frames.items[0];
        const src = full_frame.data_surface;
        const h = src.h;
        const w = src.w;

        if (w == 0 or h == 0 or split_height == 0 or h % split_height != 0) {
            return error.InvalidDimensions;
        }

        const num_frames = h / split_height;

        for (0..num_frames) |i| {
            const new_frame = try SpriteFrame.init(allocator, w, split_height);
            try self.frame_set.frames.append(allocator, new_frame);
            const dst = new_frame.data_surface;

            for (0..split_height) |y| {
                const src_row_start = (i * split_height + y) * w;
                const dst_row_start = y * w;

                // Copy RGB
                @memcpy(
                    dst.color_map[dst_row_start .. dst_row_start + w],
                    src.color_map[src_row_start .. src_row_start + w],
                );

                // Copy shadow map
                @memcpy(
                    dst.shadow_map[dst_row_start .. dst_row_start + w],
                    src.shadow_map[src_row_start .. src_row_start + w],
                );

                // Copy char map
                @memcpy(
                    dst.char_map[dst_row_start .. dst_row_start + w],
                    src.char_map[src_row_start .. src_row_start + w],
                );
            }

            // Copy to output surface for display
            try new_frame.output_surface.copy(dst);
        }

        self.frame_set.frame_idx = 1;
        self.h = split_height;
    }

    /// Splits the first frame's data_surface into a grid of equal-sized frames.
    /// Splits left-to-right first, then top-to-bottom.
    pub fn splitByWH(
        self: *Sprite,
        allocator: std.mem.Allocator,
        split_width: usize,
        split_height: usize,
    ) !void {
        const full_frame = self.frame_set.frames.items[0];
        const src = full_frame.data_surface;
        const h = src.h;
        const w = src.w;

        if (w == 0 or h == 0 or split_width == 0 or split_height == 0) {
            return error.InvalidDimensions;
        }
        if (w % split_width != 0 or h % split_height != 0) {
            return error.InvalidDimensions;
        }

        const num_cols = w / split_width;
        const num_rows = h / split_height;

        for (0..num_rows) |row| {
            for (0..num_cols) |col| {
                const new_frame =
                    try SpriteFrame.init(allocator, split_width, split_height);
                try self.frame_set.frames.append(allocator, new_frame);
                const dst = new_frame.data_surface;

                for (0..split_height) |y| {
                    const src_row_start =
                        (row * split_height + y) * w + (col * split_width);
                    const dst_row_start = y * split_width;

                    // Copy RGB
                    @memcpy(
                        dst.color_map[dst_row_start .. dst_row_start + split_width],
                        src.color_map[src_row_start .. src_row_start + split_width],
                    );

                    // Copy shadow map
                    @memcpy(
                        dst.shadow_map[dst_row_start .. dst_row_start + split_width],
                        src.shadow_map[src_row_start .. src_row_start + split_width],
                    );

                    // Copy char map
                    @memcpy(
                        dst.char_map[dst_row_start .. dst_row_start + split_width],
                        src.char_map[src_row_start .. src_row_start + split_width],
                    );
                }

                // Copy to output surface for display
                try new_frame.output_surface.copy(dst);
            }
        }

        self.frame_set.frame_idx = 1;
        self.w = split_width;
        self.h = split_height;
    }

    /// Splits the first frame's data_surface into a grid of equal-sized frames,
    /// starting at an offset position (skipping a border/header).
    /// Splits left-to-right first, then top-to-bottom.
    pub fn splitByWHOffset(
        self: *Sprite,
        allocator: std.mem.Allocator,
        split_width: usize,
        split_height: usize,
        left_offset: usize,
        top_offset: usize,
    ) !void {
        const full_frame = self.frame_set.frames.items[0];
        const src = full_frame.data_surface;
        const h = src.h;
        const w = src.w;

        if (w == 0 or h == 0 or split_width == 0 or split_height == 0) {
            return error.InvalidDimensions;
        }

        // Check if offset + at least one frame fits
        if (left_offset + split_width > w or top_offset + split_height > h) {
            return error.InvalidDimensions;
        }

        const usable_width = w - left_offset;
        const usable_height = h - top_offset;

        if (usable_width % split_width != 0 or usable_height % split_height != 0) {
            return error.InvalidDimensions;
        }

        const num_cols = usable_width / split_width;
        const num_rows = usable_height / split_height;

        for (0..num_rows) |row| {
            for (0..num_cols) |col| {
                const new_frame =
                    try SpriteFrame.init(allocator, split_width, split_height);
                try self.frame_set.frames.append(allocator, new_frame);
                const dst = new_frame.data_surface;

                for (0..split_height) |y| {
                    const src_row_start = (top_offset + row * split_height + y) * w +
                        (left_offset + col * split_width);
                    const dst_row_start = y * split_width;

                    // Copy RGB
                    @memcpy(
                        dst.color_map[dst_row_start .. dst_row_start + split_width],
                        src.color_map[src_row_start .. src_row_start + split_width],
                    );

                    // Copy shadow map
                    @memcpy(
                        dst.shadow_map[dst_row_start .. dst_row_start + split_width],
                        src.shadow_map[src_row_start .. src_row_start + split_width],
                    );

                    // Copy char map
                    @memcpy(
                        dst.char_map[dst_row_start .. dst_row_start + split_width],
                        src.char_map[src_row_start .. src_row_start + split_width],
                    );
                }

                // Copy to output surface for display
                try new_frame.output_surface.copy(dst);
            }
        }

        self.frame_set.frame_idx = 1;
        self.w = split_width;
        self.h = split_height;
    }

    /// Renders the sprite's first frame as full-block characters for debugging.
    /// Displays transparent pixels in dark blue and opaque pixels in their
    /// actual colors, useful for verifying sprite loading and pixel data.
    pub fn debugRender(self: *Sprite) !void {
        const stdout = std.io.getStdOut().writer();
        if (self.frame_set.frames.items.len == 0) return;
        for (0..self.h) |y| {
            for (0..self.w) |x| {
                const idx = x + y * self.w;
                const color =
                    self.frame_set.frames.items[0].data_surface.color_map[idx];
                const shadow =
                    self.frame_set.frames.items[0].data_surface.shadow_map[idx];
                if (shadow == 0) {
                    try stdout.print(
                        "\x1b[38;2;{d};{d};{d}m█",
                        .{ 40, 40, 80 },
                    );
                } else {
                    try stdout.print(
                        "\x1b[38;2;{};{};{}m█",
                        .{ color.r, color.g, color.b },
                    );
                }
            }
            try stdout.writeAll("\n");
        }
        try stdout.writeAll("\x1b[m");
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Sprite.splitByHeight splits vertically into equal frames" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a 16x16 sprite that we'll split into 4 frames of 16x4
    var sprite = try Sprite.init(allocator, 16, 16, "test_sprite");
    defer sprite.deinit(allocator);

    const frame0 = sprite.frame_set.frames.items[0];
    const surface = frame0.data_surface;

    // Paint each 16x4 region with a unique color
    const colors = [_]movy.core.types.Rgb{
        .{ .r = 255, .g = 0, .b = 0 }, // Red - top
        .{ .r = 0, .g = 255, .b = 0 }, // Green
        .{ .r = 0, .g = 0, .b = 255 }, // Blue
        .{ .r = 255, .g = 255, .b = 0 }, // Yellow - bottom
    };

    for (0..4) |region| {
        for (0..4) |y| {
            for (0..16) |x| {
                const idx = (region * 4 + y) * 16 + x;
                surface.color_map[idx] = colors[region];
                surface.shadow_map[idx] = 200 + @as(u8, @intCast(region)); // Unique alpha per region
            }
        }
    }

    // Split into 4 frames of height 4
    try sprite.splitByHeight(allocator, 4);

    // Verify we have 5 frames (original + 4 split)
    try testing.expectEqual(@as(usize, 5), sprite.frame_set.frames.items.len);
    try testing.expectEqual(@as(usize, 4), sprite.h);

    // Verify each frame has correct color and alpha
    for (1..5) |frame_idx| {
        const frame = sprite.frame_set.frames.items[frame_idx];
        const expected_color = colors[frame_idx - 1];
        const expected_alpha = 200 + @as(u8, @intCast(frame_idx - 1));

        // Check all pixels in the frame
        for (0..4) |y| {
            for (0..16) |x| {
                const idx = y * 16 + x;
                try testing.expectEqual(
                    expected_color.r,
                    frame.data_surface.color_map[idx].r,
                );
                try testing.expectEqual(
                    expected_color.g,
                    frame.data_surface.color_map[idx].g,
                );
                try testing.expectEqual(
                    expected_color.b,
                    frame.data_surface.color_map[idx].b,
                );
                try testing.expectEqual(
                    expected_alpha,
                    frame.data_surface.shadow_map[idx],
                );
            }
        }

        // Test edge pixels specifically (top-left, top-right, bottom-left, bottom-right)
        const edges = [_]usize{ 0, 15, 16 * 3, 16 * 3 + 15 };
        for (edges) |edge_idx| {
            try testing.expectEqual(
                expected_color.r,
                frame.data_surface.color_map[edge_idx].r,
            );
            try testing.expectEqual(
                expected_alpha,
                frame.data_surface.shadow_map[edge_idx],
            );
        }
    }
}

test "Sprite.splitByHeight handles edge pixels correctly" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create 10x10 sprite, split into 5 frames of 10x2
    var sprite = try Sprite.init(allocator, 10, 10, "edge_test");
    defer sprite.deinit(allocator);

    const surface = sprite.frame_set.frames.items[0].data_surface;

    // Set unique color for EACH pixel
    for (0..10) |y| {
        for (0..10) |x| {
            const idx = y * 10 + x;
            surface.color_map[idx] = .{
                .r = @intCast(y * 10 + x),
                .g = @intCast(y),
                .b = @intCast(x),
            };
        }
    }

    try sprite.splitByHeight(allocator, 2);

    // Verify edge boundaries between frames
    // Frame 1: rows 0-1, Frame 2: rows 2-3, etc.
    for (1..6) |frame_idx| {
        const frame = sprite.frame_set.frames.items[frame_idx];
        const orig_y_start = (frame_idx - 1) * 2;

        // Check first row (y=0 in frame)
        for (0..10) |x| {
            const frame_idx_pos = x;
            const orig_idx = orig_y_start * 10 + x;
            try testing.expectEqual(
                surface.color_map[orig_idx].r,
                frame.data_surface.color_map[frame_idx_pos].r,
            );
        }

        // Check last row (y=1 in frame)
        for (0..10) |x| {
            const frame_idx_pos = 10 + x;
            const orig_idx = (orig_y_start + 1) * 10 + x;
            try testing.expectEqual(
                surface.color_map[orig_idx].r,
                frame.data_surface.color_map[frame_idx_pos].r,
            );
        }
    }
}

test "Sprite.splitByWH splits 2x2 grid correctly" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create 32x16 sprite, split into 2x2 grid (4 frames of 16x8)
    var sprite = try Sprite.init(allocator, 32, 16, "grid_test");
    defer sprite.deinit(allocator);

    const surface = sprite.frame_set.frames.items[0].data_surface;

    // Paint 4 quadrants with different colors
    // Top-left: Red, Top-right: Green, Bottom-left: Blue, Bottom-right: Yellow
    const colors = [_]movy.core.types.Rgb{
        .{ .r = 255, .g = 0, .b = 0 }, // Top-left
        .{ .r = 0, .g = 255, .b = 0 }, // Top-right
        .{ .r = 0, .g = 0, .b = 255 }, // Bottom-left
        .{ .r = 255, .g = 255, .b = 0 }, // Bottom-right
    };

    for (0..2) |row| {
        for (0..2) |col| {
            const color = colors[row * 2 + col];
            for (0..8) |y| {
                for (0..16) |x| {
                    const idx = (row * 8 + y) * 32 + (col * 16 + x);
                    surface.color_map[idx] = color;
                    surface.shadow_map[idx] =
                        100 + @as(u8, @intCast(row * 2 + col));
                }
            }
        }
    }

    // Split into 16x8 frames
    try sprite.splitByWH(allocator, 16, 8);

    // Verify we have 5 frames (original + 4 split)
    try testing.expectEqual(@as(usize, 5), sprite.frame_set.frames.items.len);
    try testing.expectEqual(@as(usize, 16), sprite.w);
    try testing.expectEqual(@as(usize, 8), sprite.h);

    // Verify frame order: top-left, top-right, bottom-left, bottom-right
    for (1..5) |frame_idx| {
        const frame = sprite.frame_set.frames.items[frame_idx];
        const expected_color = colors[frame_idx - 1];
        const expected_alpha = 100 + @as(u8, @intCast(frame_idx - 1));

        // Check all pixels
        for (0..8) |y| {
            for (0..16) |x| {
                const idx = y * 16 + x;
                try testing.expectEqual(
                    expected_color.r,
                    frame.data_surface.color_map[idx].r,
                );
                try testing.expectEqual(
                    expected_color.g,
                    frame.data_surface.color_map[idx].g,
                );
                try testing.expectEqual(
                    expected_color.b,
                    frame.data_surface.color_map[idx].b,
                );
                try testing.expectEqual(
                    expected_alpha,
                    frame.data_surface.shadow_map[idx],
                );
            }
        }
    }
}

test "Sprite.splitByWH handles edge boundaries correctly" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create 20x10 sprite, split into 2x2 grid (4 frames of 10x5)
    var sprite = try Sprite.init(allocator, 20, 10, "edge_grid_test");
    defer sprite.deinit(allocator);

    const surface = sprite.frame_set.frames.items[0].data_surface;

    // Set unique value for each pixel
    for (0..10) |y| {
        for (0..20) |x| {
            const idx = y * 20 + x;
            surface.color_map[idx] = .{
                .r = @intCast(x),
                .g = @intCast(y),
                .b = @intCast((y * 20 + x) % 256),
            };
        }
    }

    try sprite.splitByWH(allocator, 10, 5);

    // Frame 1: rows 0-4, cols 0-9
    // Frame 2: rows 0-4, cols 10-19
    // Frame 3: rows 5-9, cols 0-9
    // Frame 4: rows 5-9, cols 10-19

    const frame_coords = [_][2]usize{
        .{ 0, 0 }, // Frame 1: top-left
        .{ 0, 10 }, // Frame 2: top-right
        .{ 5, 0 }, // Frame 3: bottom-left
        .{ 5, 10 }, // Frame 4: bottom-right
    };

    for (1..5) |frame_idx| {
        const frame = sprite.frame_set.frames.items[frame_idx];
        const base_y = frame_coords[frame_idx - 1][0];
        const base_x = frame_coords[frame_idx - 1][1];

        // Check corners
        const corners = [_][2]usize{
            .{ 0, 0 }, // top-left
            .{ 0, 9 }, // top-right
            .{ 4, 0 }, // bottom-left
            .{ 4, 9 }, // bottom-right
        };

        for (corners) |corner| {
            const frame_y = corner[0];
            const frame_x = corner[1];
            const orig_y = base_y + frame_y;
            const orig_x = base_x + frame_x;

            const frame_idx_pos = frame_y * 10 + frame_x;
            const orig_idx = orig_y * 20 + orig_x;

            try testing.expectEqual(
                surface.color_map[orig_idx].r,
                frame.data_surface.color_map[frame_idx_pos].r,
            );
            try testing.expectEqual(
                surface.color_map[orig_idx].g,
                frame.data_surface.color_map[frame_idx_pos].g,
            );
        }
    }
}

test "Sprite.splitByWHOffset skips border correctly" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create 36x16 sprite with 4-pixel border on left/top sides
    // Usable area: 32x12, split into 2x2 grid of 16x6 frames
    var sprite = try Sprite.init(allocator, 36, 16, "offset_test");
    defer sprite.deinit(allocator);

    const surface = sprite.frame_set.frames.items[0].data_surface;

    // Fill border with black
    for (0..16) |y| {
        for (0..36) |x| {
            const idx = y * 36 + x;
            surface.color_map[idx] = .{ .r = 0, .g = 0, .b = 0 };
            surface.shadow_map[idx] = 50; // Low alpha for border
        }
    }

    // Fill 4 quadrants inside border with different colors
    const colors = [_]movy.core.types.Rgb{
        .{ .r = 255, .g = 0, .b = 0 }, // Top-left
        .{ .r = 0, .g = 255, .b = 0 }, // Top-right
        .{ .r = 0, .g = 0, .b = 255 }, // Bottom-left
        .{ .r = 255, .g = 255, .b = 0 }, // Bottom-right
    };

    for (0..2) |row| {
        for (0..2) |col| {
            const color = colors[row * 2 + col];
            for (0..6) |y| {
                for (0..16) |x| {
                    const idx = (4 + row * 6 + y) * 36 + (4 + col * 16 + x);
                    surface.color_map[idx] = color;
                    surface.shadow_map[idx] =
                        200 + @as(u8, @intCast(row * 2 + col));
                }
            }
        }
    }

    // Split with offset (4, 4)
    try sprite.splitByWHOffset(allocator, 16, 6, 4, 4);

    // Verify we have 5 frames
    try testing.expectEqual(@as(usize, 5), sprite.frame_set.frames.items.len);

    // Verify frames contain colored data, not border
    for (1..5) |frame_idx| {
        const frame = sprite.frame_set.frames.items[frame_idx];
        const expected_color = colors[frame_idx - 1];
        const expected_alpha = 200 + @as(u8, @intCast(frame_idx - 1));

        // Check first and last pixel
        try testing.expectEqual(
            expected_color.r,
            frame.data_surface.color_map[0].r,
        );
        try testing.expectEqual(
            expected_alpha,
            frame.data_surface.shadow_map[0],
        );

        const last_idx = 16 * 6 - 1;
        try testing.expectEqual(
            expected_color.r,
            frame.data_surface.color_map[last_idx].r,
        );
        try testing.expectEqual(
            expected_alpha,
            frame.data_surface.shadow_map[last_idx],
        );
    }
}

test "Sprite.splitByWHOffset validates offset dimensions" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sprite = try Sprite.init(allocator, 32, 16, "offset_validation");
    defer sprite.deinit(allocator);

    // Should fail: offset too large (no room for frame)
    const result1 = sprite.splitByWHOffset(allocator, 16, 8, 20, 10);
    try testing.expectError(error.InvalidDimensions, result1);

    // Should fail: usable area not evenly divisible
    const result2 = sprite.splitByWHOffset(allocator, 13, 7, 2, 0);
    try testing.expectError(error.InvalidDimensions, result2);
}

test "Sprite split functions preserve char_map" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sprite = try Sprite.init(allocator, 20, 10, "char_test");
    defer sprite.deinit(allocator);

    const surface = sprite.frame_set.frames.items[0].data_surface;

    // Set unique char for each pixel
    for (0..10) |y| {
        for (0..20) |x| {
            const idx = y * 20 + x;
            surface.char_map[idx] = 'A' + @as(u21, @intCast(idx % 26));
        }
    }

    try sprite.splitByWH(allocator, 10, 5);

    // Verify char_map is preserved
    const frame = sprite.frame_set.frames.items[1]; // Top-left frame
    for (0..5) |y| {
        for (0..10) |x| {
            const frame_idx_pos = y * 10 + x;
            const orig_idx = y * 20 + x;
            try testing.expectEqual(
                surface.char_map[orig_idx],
                frame.data_surface.char_map[frame_idx_pos],
            );
        }
    }
}
