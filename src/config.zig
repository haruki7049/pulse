//! Global tempo and audio format of the drum solo.

const meters = @import("meters");

/// Sample type used for synthesis and mixing.
pub const T = f64;

/// Tempo in quarter-note beats per minute.
pub const BPM: usize = 190;
/// Meter of the whole piece.
pub const TIME_SIGNATURE: meters.TimeSignature = .{ .numerator = 4, .denominator = 4 };
/// Length of the piece in bars (~30 seconds at 190 BPM).
pub const TOTAL_BARS: usize = 24;

pub const SAMPLE_RATE: u32 = 44100;
pub const CHANNELS: u16 = 2;

/// Peak level the final mix is normalized to (about -1 dBFS).
pub const PEAK: T = 0.89;
