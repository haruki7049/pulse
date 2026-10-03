//! Arranges the score on a sequencer and renders the drum solo.

const std = @import("std");
const lightmix = @import("lightmix");
const meters = @import("meters");
const sequencer = @import("sequencer");
const config = @import("./config.zig");
const kit = @import("./kit.zig");
const pattern = @import("./pattern.zig");

const T = config.T;

/// Renders the whole piece: every hit of the score on one four-lane kit instrument,
/// padded with silence to exactly `TOTAL_BARS` bars and normalized to `PEAK`.
pub fn render(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const hits = try pattern.score(allocator);
    defer allocator.free(hits);

    var seq = sequencer.Sequencer(T).init(allocator, config.BPM, config.TIME_SIGNATURE, config.SAMPLE_RATE, config.CHANNELS);
    defer seq.deinit();

    var drum_kit = try seq.createInstrument("DrumKit", kit.lane_count);
    defer drum_kit.deinit(allocator);

    for (hits) |h| {
        const wave = try kit.gen(allocator, h.voice, h.velocity);
        try seq.addInstrument(drum_kit, @intFromEnum(h.voice.lane()), wave, .{ .bar = h.bar, .beat = h.beat });
    }

    var wave = try seq.render();
    errdefer wave.deinit();

    try pad(allocator, &wave, try totalFrames());
    normalize(&wave, config.PEAK);
    return wave;
}

/// Number of frames in `TOTAL_BARS` bars.
pub fn totalFrames() !usize {
    const end = meters.Position{ .bar = config.TOTAL_BARS };
    return end.toSampleOffset(config.BPM, config.TIME_SIGNATURE, config.SAMPLE_RATE);
}

/// Extends `wave` with silence up to `frames` frames, so the final break is part of the file.
fn pad(allocator: std.mem.Allocator, wave: *lightmix.Wave(T), frames: usize) !void {
    const len = frames * wave.channels;
    if (wave.samples.len >= len) return;

    const samples = try allocator.alloc(T, len);
    @memcpy(samples[0..wave.samples.len], wave.samples);
    @memset(samples[wave.samples.len..], 0);
    allocator.free(wave.samples);
    wave.samples = samples;
}

/// Scales `wave` so its absolute peak equals `peak` (no-op for silence).
fn normalize(wave: *lightmix.Wave(T), peak: T) void {
    var max: T = 0;
    for (wave.samples) |s| max = @max(max, @abs(s));
    if (max == 0) return;
    const gain = peak / max;
    for (@constCast(wave.samples)) |*s| s.* *= gain;
}

test "render produces exactly 24 bars normalized to the target peak" {
    const allocator = std.testing.allocator;
    var wave = try render(allocator);
    defer wave.deinit();

    try std.testing.expectEqual(config.SAMPLE_RATE, wave.sample_rate);
    try std.testing.expectEqual(config.CHANNELS, wave.channels);
    try std.testing.expectEqual(try totalFrames() * config.CHANNELS, wave.samples.len);

    var max: T = 0;
    for (wave.samples) |s| max = @max(max, @abs(s));
    try std.testing.expectApproxEqAbs(config.PEAK, max, 1e-9);

    // The break: by the last beat of the final bar only the tail of the final hit is left (< -60 dB).
    const last_beat = meters.Position{ .bar = config.TOTAL_BARS - 1, .beat = 3.0 };
    const start = try last_beat.toSampleOffset(config.BPM, config.TIME_SIGNATURE, config.SAMPLE_RATE);
    for (wave.samples[start * config.CHANNELS ..]) |s| try std.testing.expect(@abs(s) < 1e-3);
}

test "totalFrames is about 30 seconds" {
    const seconds = @as(f64, @floatFromInt(try totalFrames())) / @as(f64, @floatFromInt(config.SAMPLE_RATE));
    try std.testing.expect(seconds > 30.0 and seconds < 31.0);
}

test {
    std.testing.refAllDecls(@This());
}
