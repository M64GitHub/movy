//! Rendering pipeline and effect system for terminal graphics.
//!
//! This module exports the effect system, render engine, pipelines,
//! and compositing tools for creating layered terminal visuals.

pub const Effect = @import("effect.zig").Effect;
pub const RenderEffect = @import("RenderEffect.zig").RenderEffect;
pub const RenderEffectError = @import("RenderEffect.zig").Error;
pub const RenderEffectChain = @import("RenderEffectChain.zig").RenderEffectChain;
pub const RenderObject = @import("RenderObject.zig").RenderObject;
pub const RenderPipeline = @import("RenderPipeline.zig").RenderPipeline;
pub const RenderPipelineError = @import("RenderPipeline.zig").Error;
pub const RenderEngine = @import("RenderEngine.zig").RenderEngine;
