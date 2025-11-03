/// Represents an RGB color for terminal rendering in movy.
/// Each component (red, green, blue) is an 8-bit value, defaulting to 0 (black).
pub const Rgb = struct {
    r: u8 = 0x00, // Red component (0-255)
    g: u8 = 0x00, // Green component (0-255)
    b: u8 = 0x00, // Blue component (0-255)
};

/// Represents dimensions (width and height) in pixels or characters.
pub const Size = struct {
    w: usize,
    h: usize,
};

/// 2D coordinates with signed integer values.
pub const Coords2D = struct {
    x: i32,
    y: i32,
};

/// 3D coordinates with signed integer values (includes z-index).
pub const Coords3D = struct {
    x: i32,
    y: i32,
    z: i32,
};

/// Defines a 2D pixel with position and color for movy rendering.
/// Used to represent points in terminal interfaces or render surfaces.
pub const Pixel2D = struct {
    x: i32, // X-coordinate in 2D space
    y: i32, // Y-coordinate in 2D space
    c: Rgb, // RGB color of the pixel
};
