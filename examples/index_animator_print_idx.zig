const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const modes = [_]movy.animation.IndexAnimator.LoopMode{
        .once,
        .loopForward,
        .loopBackwards,
        .loopBounce,
    };

    for (modes) |mode| {
        // Len 5: 0-4
        var anim = movy.animation.IndexAnimator.init(
            0,
            4,
            mode,
        );

        // 3 loops for bounce, 2 for others
        const steps: usize = if (mode == .loopBounce) 15 else 10;
        std.debug.print("{s}: ", .{@tagName(mode)});
        var idx: usize = anim.start;
        for (0..steps) |i| {
            std.debug.print("{d} ", .{idx});
            idx = anim.step();
            if (i == steps - 1) std.debug.print("\n", .{});
        }
    }
}
