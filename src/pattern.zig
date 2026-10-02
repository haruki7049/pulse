//! The 24-bar drum solo score, written directly as Zig code.
//!
//! Bars are 0-indexed and beats are quarter notes (4/4), so a 16th note is 0.25 beats.
//! - Bars 0..7: driving 190 BPM groove with open/closed hi-hat choke work.
//! - Bars 8..15: snare ghost notes under syncopated snare and kick accents.
//! - Bars 16..23: fast tom fills, kick/snare runs, a 32nd-note roll, and a final hit on the
//!   downbeat of the last bar followed by a break (silence).

const std = @import("std");
const config = @import("./config.zig");
const Voice = @import("./kit.zig").Voice;

const T = config.T;

/// One drum hit in the score.
pub const Hit = struct {
    bar: usize,
    beat: f64,
    voice: Voice,
    velocity: T = 1.0,
};

/// Collects hits while the score is written.
const Score = struct {
    allocator: std.mem.Allocator,
    hits: std.ArrayList(Hit) = .empty,

    fn hit(self: *Score, bar: usize, beat: f64, voice: Voice, velocity: T) !void {
        try self.hits.append(self.allocator, .{ .bar = bar, .beat = beat, .voice = voice, .velocity = velocity });
    }

    /// Adds a hit on the `index`-th 16th note of `bar`.
    fn sixteenth(self: *Score, bar: usize, index: usize, voice: Voice, velocity: T) !void {
        try self.hit(bar, @as(f64, @floatFromInt(index)) * 0.25, voice, velocity);
    }
};

/// Linear interpolation used for crescendos.
fn ramp(from: T, to: T, step: usize, steps: usize) T {
    if (steps <= 1) return to;
    const t: T = @as(T, @floatFromInt(step)) / @as(T, @floatFromInt(steps - 1));
    return from + (to - from) * t;
}

fn contains(set: []const usize, value: usize) bool {
    return std.mem.indexOfScalar(usize, set, value) != null;
}

/// Bars 0..7: driving beat with hi-hat choke work.
fn groove(s: *Score) !void {
    for (0..8) |bar| {
        const odd = bar % 2 == 1;

        // Kick: downbeats plus pushes that vary every other bar.
        const kicks: []const usize = if (odd) &.{ 0, 3, 8, 10 } else &.{ 0, 6, 8 };
        for (kicks) |i| try s.sixteenth(bar, i, .kick, 1.0);

        // Snare backbeat on 2 and 4, except where the bar 7 fill takes over.
        try s.sixteenth(bar, 4, .snare, 0.95);
        if (bar != 7) try s.sixteenth(bar, 12, .snare, 0.95);

        // Hi-hat 8ths. Open hats on the "and" of 4 (and of 2 on odd bars) ring until the next
        // closed hat on the same lane chokes them.
        for (0..8) |eighth| {
            const index = eighth * 2;
            if (bar == 7 and index >= 12) break;
            const open = (index == 14) or (odd and index == 6) or (bar == 0 and index == 0);
            const accent: T = if (eighth % 2 == 0) 0.8 else 0.55;
            try s.sixteenth(bar, index, if (open) .open_hihat else .closed_hihat, if (open) 0.75 else accent);
        }

        // Bar 7: snare 16ths into the solo section.
        if (bar == 7) {
            for (12..16, 0..) |i, step| try s.sixteenth(bar, i, .snare, ramp(0.6, 1.0, step, 4));
        }
    }
}

/// Bars 8..15: ghost-note solo with syncopated accents. Index lists are 16th-note positions.
fn ghostSolo(s: *Score) !void {
    const accents = [8][]const usize{
        &.{ 4, 7, 10, 12 },
        &.{ 4, 11, 14 },
        &.{ 3, 6, 12 },
        &.{ 4, 9, 12, 15 },
        &.{ 2, 5, 10, 13 },
        &.{ 4, 7, 12, 14 },
        &.{ 1, 6, 9, 12, 15 },
        &.{4},
    };
    const kicks = [8][]const usize{
        &.{ 0, 6, 8 },
        &.{ 0, 3, 8, 13 },
        &.{ 0, 8, 11 },
        &.{ 0, 6, 10, 14 },
        &.{ 0, 3, 8, 11 },
        &.{ 0, 6, 10 },
        &.{ 0, 4, 8, 11, 14 },
        &.{ 0, 2 },
    };

    for (0..8) |n| {
        const bar = 8 + n;
        for (kicks[n]) |i| try s.sixteenth(bar, i, .kick, 0.95);

        // Quarter-note closed hats keep time under the solo; an open hat on bars 11 and 15
        // is choked by the hat on the next downbeat.
        for (0..4) |q| try s.sixteenth(bar, q * 4, .closed_hihat, 0.5);
        if (n == 3) try s.sixteenth(bar, 14, .open_hihat, 0.6);

        for (0..16) |i| {
            if (n == 7 and i >= 8) {
                // Bar 15: second half is a crescendo snare roll.
                try s.sixteenth(bar, i, .snare, ramp(0.4, 1.0, i - 8, 8));
            } else if (contains(accents[n], i)) {
                try s.sixteenth(bar, i, .snare, 0.95);
            } else if (!contains(kicks[n], i)) {
                try s.sixteenth(bar, i, .snare, 0.18);
            }
        }
    }
}

/// Bars 16..23: tom fills, kick/snare runs, a roll, and the final hit plus break.
fn finale(s: *Score) !void {
    const toms = [_]Voice{ .high_tom, .high_tom, .mid_tom, .mid_tom, .floor_tom, .floor_tom };

    // Bars 16..17: half-bar groove, then a descending sextuplet tom run.
    for (16..18) |bar| {
        try s.hit(bar, 0.0, .kick, 1.0);
        try s.hit(bar, 1.0, .snare, 0.95);
        for (0..4) |e| try s.hit(bar, @as(f64, @floatFromInt(e)) * 0.5, .closed_hihat, 0.6);
        for (0..12) |k| {
            const beat = 2.0 + @as(f64, @floatFromInt(k)) / 6.0;
            try s.hit(bar, beat, toms[(k / 2) % toms.len], 0.85);
        }
        try s.hit(bar, 2.0, .kick, 0.9);
        try s.hit(bar, 3.0, .kick, 0.9);
    }

    // Bars 18..19: whole bars of sextuplet toms around the kit with kicks on every beat.
    for (18..20) |bar| {
        for (0..24) |k| {
            const beat = @as(f64, @floatFromInt(k)) / 6.0;
            const voice = toms[k % toms.len];
            const accent: T = if (k % 6 == 0) 1.0 else 0.75;
            try s.hit(bar, beat, voice, accent);
        }
        for (0..4) |b| try s.hit(bar, @floatFromInt(b), .kick, 0.95);
    }

    // Bars 20..21: alternating kick/snare 16ths, building over two bars.
    for (20..22, 0..) |bar, half| {
        for (0..16) |i| {
            const velocity = ramp(0.55, 1.0, half * 16 + i, 32);
            try s.sixteenth(bar, i, if (i % 2 == 0) .kick else .snare, velocity);
        }
        for (0..4) |q| try s.sixteenth(bar, q * 4, .closed_hihat, 0.55);
    }

    // Bar 22: 32nd-note snare roll with kicks on the beats and floor toms on the last four.
    for (0..32) |k| {
        const beat = @as(f64, @floatFromInt(k)) * 0.125;
        try s.hit(22, beat, .snare, ramp(0.3, 1.0, k, 32));
        if (k >= 28) try s.hit(22, beat, .floor_tom, 0.9);
    }
    for (0..4) |b| try s.hit(22, @floatFromInt(b), .kick, 0.9);

    // Bar 23: final hit on the downbeat, then silence for the rest of the bar.
    try s.hit(23, 0.0, .kick, 1.0);
    try s.hit(23, 0.0, .snare, 1.0);
    try s.hit(23, 0.0, .open_hihat, 1.0);
    try s.hit(23, 0.0, .floor_tom, 1.0);
}

/// Writes the whole score. The caller owns the returned slice.
pub fn score(allocator: std.mem.Allocator) ![]Hit {
    var s = Score{ .allocator = allocator };
    errdefer s.hits.deinit(allocator);

    try groove(&s);
    try ghostSolo(&s);
    try finale(&s);

    return s.hits.toOwnedSlice(allocator);
}

test "score stays inside 24 bars of 4/4" {
    const allocator = std.testing.allocator;
    const hits = try score(allocator);
    defer allocator.free(hits);

    try std.testing.expect(hits.len > 0);
    for (hits) |h| {
        try std.testing.expect(h.bar < config.TOTAL_BARS);
        try std.testing.expect(h.beat >= 0.0 and h.beat < 4.0);
        try std.testing.expect(h.velocity > 0.0 and h.velocity <= 1.0);
    }
}

test "every section has hits and the last bar is one hit followed by a break" {
    const allocator = std.testing.allocator;
    const hits = try score(allocator);
    defer allocator.free(hits);

    var per_section = [_]usize{ 0, 0, 0 };
    var last_bar: usize = 0;
    for (hits) |h| {
        per_section[h.bar / 8] += 1;
        if (h.bar == 23) {
            last_bar += 1;
            try std.testing.expectEqual(@as(f64, 0.0), h.beat);
        }
    }
    for (per_section) |n| try std.testing.expect(n > 0);
    try std.testing.expectEqual(@as(usize, 4), last_bar);
}

test "groove section chokes open hi-hats with a later closed hi-hat" {
    const allocator = std.testing.allocator;
    const hits = try score(allocator);
    defer allocator.free(hits);

    const ring_beats = Voice.open_hihat.seconds() * @as(f64, @floatFromInt(config.BPM)) / 60.0;
    var chokes: usize = 0;
    for (hits) |open| {
        if (open.voice != .open_hihat or open.bar >= 8) continue;
        const open_at = @as(f64, @floatFromInt(open.bar)) * 4.0 + open.beat;
        for (hits) |closed| {
            if (closed.voice != .closed_hihat) continue;
            const closed_at = @as(f64, @floatFromInt(closed.bar)) * 4.0 + closed.beat;
            if (closed_at > open_at and closed_at - open_at < ring_beats) {
                chokes += 1;
                break;
            }
        }
    }
    try std.testing.expect(chokes >= 8);
}

test "ghost-note section has quiet snares under the accents" {
    const allocator = std.testing.allocator;
    const hits = try score(allocator);
    defer allocator.free(hits);

    var ghosts: usize = 0;
    for (hits) |h| {
        if (h.bar >= 8 and h.bar < 16 and h.voice == .snare and h.velocity < 0.3) ghosts += 1;
    }
    try std.testing.expect(ghosts >= 50);
}

test {
    std.testing.refAllDecls(@This());
}
