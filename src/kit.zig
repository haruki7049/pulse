//! Drum kit voices, their lanes, and their timbrefolio synthesis settings.
//!
//! The kit is one `resonator.Instrument` with four lanes. Each lane is a monophonic track, so a
//! new hit on a lane cuts the previous one with a short micro-fade. The closed and open hi-hats
//! share lane 2 on purpose: a closed hat after an open hat chokes it, like a real hi-hat pedal.

const std = @import("std");
const lightmix = @import("lightmix");
const drums = @import("timbrefolio").drums;
const config = @import("./config.zig");

const T = config.T;

/// Lanes (instrument strings) of the drum kit.
pub const Lane = enum(usize) {
    kick = 0,
    snare = 1,
    hihat = 2,
    tom = 3,
};

/// Number of lanes created on the kit instrument.
pub const lane_count: usize = @typeInfo(Lane).@"enum".fields.len;

/// A playable drum sound.
pub const Voice = enum {
    kick,
    snare,
    closed_hihat,
    open_hihat,
    high_tom,
    mid_tom,
    floor_tom,

    /// Returns the lane this voice is played on.
    pub fn lane(self: Voice) Lane {
        return switch (self) {
            .kick => .kick,
            .snare => .snare,
            .closed_hihat, .open_hihat => .hihat,
            .high_tom, .mid_tom, .floor_tom => .tom,
        };
    }

    /// Rendered length in seconds, long enough for each decay to reach about -50 dB.
    pub fn seconds(self: Voice) T {
        return switch (self) {
            .kick => 0.40,
            .snare => 0.30,
            .closed_hihat => 0.16,
            .open_hihat => 1.00,
            .high_tom, .mid_tom, .floor_tom => 0.50,
        };
    }
};

/// Synthesizes one hit of `voice` at `velocity` (0.0 to 1.0).
pub fn gen(allocator: std.mem.Allocator, voice: Voice, velocity: T) !lightmix.Wave(T) {
    const sr: T = @floatFromInt(config.SAMPLE_RATE);
    const length: usize = @intFromFloat(voice.seconds() * sr);
    const sample_rate = config.SAMPLE_RATE;
    const channels = config.CHANNELS;

    return switch (voice) {
        .kick => drums.kick.Kick.gen(T, allocator, sample_rate, channels, length, velocity, .{}),
        .snare => drums.snare.Snare.gen(T, allocator, sample_rate, channels, length, velocity, .{}),
        .closed_hihat => drums.closed_hihat.ClosedHihat.gen(T, allocator, sample_rate, channels, length, velocity, .{}),
        .open_hihat => drums.open_hihat.OpenHihat.gen(T, allocator, sample_rate, channels, length, velocity, .{ .decay_rate = 6.0 }),
        .high_tom => drums.tom.Tom.gen(T, allocator, sample_rate, channels, length, velocity, .{ .start_frequency = 260.0, .end_frequency = 180.0 }),
        .mid_tom => drums.tom.Tom.gen(T, allocator, sample_rate, channels, length, velocity, .{}),
        .floor_tom => drums.tom.Tom.gen(T, allocator, sample_rate, channels, length, velocity, .{ .start_frequency = 140.0, .end_frequency = 85.0 }),
    };
}

test "hi-hats share a lane and every voice maps to a kit lane" {
    try std.testing.expectEqual(@as(usize, 4), lane_count);
    try std.testing.expectEqual(Lane.kick, Voice.kick.lane());
    try std.testing.expectEqual(Lane.snare, Voice.snare.lane());
    try std.testing.expectEqual(Voice.closed_hihat.lane(), Voice.open_hihat.lane());
    try std.testing.expectEqual(Lane.hihat, Voice.open_hihat.lane());
    inline for (.{ Voice.high_tom, Voice.mid_tom, Voice.floor_tom }) |v| {
        try std.testing.expectEqual(Lane.tom, v.lane());
    }
}

test "gen renders every voice in the configured format" {
    const allocator = std.testing.allocator;
    inline for (@typeInfo(Voice).@"enum".fields) |field| {
        const voice: Voice = @enumFromInt(field.value);
        var wave = try gen(allocator, voice, 0.8);
        defer wave.deinit();

        try std.testing.expectEqual(config.SAMPLE_RATE, wave.sample_rate);
        try std.testing.expectEqual(config.CHANNELS, wave.channels);
        try std.testing.expect(wave.samples.len > 0);
    }
}

test {
    std.testing.refAllDecls(@This());
}
