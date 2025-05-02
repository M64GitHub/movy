const Effects = @import("RenderEffect.zig");

/// Everything effect‑related lives here
pub const Effect = struct {
    /// The tagged‑union of all effect parameter variants
    pub const SurfaceExpand = Effects.SurfaceExpand;
    pub const RenderEffectContext = Effects.RenderEffectContext;
    pub const EffectDirection = Effects.EffectDirection;

    /// Effects
    pub const Dummy = @import("effects/Dummy.zig").DummyEffect;
    pub const Fade = @import("effects/Fade.zig").Fade;
    pub const Blur = @import("effects/Blur.zig").Blur;
    pub const Brighter = @import("effects/Brighter.zig").Brighter;
    pub const Darker = @import("effects/Darker.zig").Darker;
    pub const OutlineRotator = @import("effects/OutlineRotator.zig").OutlineRotator;
};
