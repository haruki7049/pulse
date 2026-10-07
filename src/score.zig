//! The 24-bar drum solo score: one `meters.Phrase` per kit lane, written in `score/*.zon`.
//!
//! Bars are 0-indexed and beats are quarter notes (4/4), so a 16th note is 0.25 beats.
//! - Bars 0..7: driving 190 BPM groove with open/closed hi-hat choke work.
//! - Bars 8..15: snare ghost notes under syncopated snare and kick accents.
//! - Bars 16..23: fast tom fills, kick/snare runs, a 32nd-note roll, and a final hit on the
//!   downbeat of the last bar followed by a break (silence).
//!
//! A note's payload is a `kit.Note(lane)`: `.voice` defaults to the lane's main voice and
//! `.velocity` to 1.0, so `.note = .{}` is a full-velocity hit of that voice. Drums are one-shots,
//! so `duration_beats` is not written and not used.

const std = @import("std");
const meters = @import("meters");
const config = @import("./config.zig");
const kit = @import("./kit.zig");

const Lane = kit.Lane;

/// Score of one kit lane.
pub fn Phrase(comptime lane: Lane) type {
    return meters.Phrase(kit.Note(lane));
}

/// Returns the score of `lane`, loaded from `score/<lane>.zon` at comptime.
pub fn phrase(comptime lane: Lane) Phrase(lane) {
    return switch (lane) {
        .kick => @import("./score/kick.zon"),
        .snare => @import("./score/snare.zon"),
        .hihat => @import("./score/hihat.zon"),
        .tom => @import("./score/tom.zon"),
    };
}

/// Absolute position of a note in beats from the start of the piece.
fn beats(note: anytype) f64 {
    const beats_per_bar: f64 = @floatFromInt(config.TIME_SIGNATURE.numerator);
    return @as(f64, @floatFromInt(note.bar)) * beats_per_bar + note.beat;
}

test "every note stays inside 24 bars of 4/4 and plays a voice of its lane" {
    inline for (@typeInfo(Lane).@"enum".fields) |field| {
        const lane: Lane = @enumFromInt(field.value);
        const p = phrase(lane);
        try std.testing.expect(p.notes.len > 0);
        for (p.notes) |n| {
            try std.testing.expect(n.bar < config.TOTAL_BARS);
            try std.testing.expect(n.beat >= 0.0 and n.beat < 4.0);
            try std.testing.expect(n.note.velocity > 0.0 and n.note.velocity <= 1.0);
            try std.testing.expectEqual(lane, n.note.voice.lane());
        }
    }
}

test "every lane is written in time order" {
    inline for (@typeInfo(Lane).@"enum".fields) |field| {
        const notes = phrase(@enumFromInt(field.value)).notes;
        for (notes[0 .. notes.len - 1], notes[1..]) |a, b| {
            try std.testing.expect(beats(a) < beats(b));
        }
    }
}

test "every section has hits and the last bar is one hit followed by a break" {
    var per_section = [_]usize{ 0, 0, 0 };
    var last_bar: usize = 0;
    inline for (@typeInfo(Lane).@"enum".fields) |field| {
        for (phrase(@enumFromInt(field.value)).notes) |n| {
            per_section[n.bar / 8] += 1;
            if (n.bar == 23) {
                last_bar += 1;
                try std.testing.expectEqual(@as(f64, 0.0), n.beat);
            }
        }
    }
    for (per_section) |n| try std.testing.expect(n > 0);
    try std.testing.expectEqual(@as(usize, 4), last_bar);
}

test "groove section chokes open hi-hats with a later closed hi-hat" {
    const notes = phrase(.hihat).notes;
    const ring_beats = kit.Voice.open_hihat.seconds() * @as(f64, @floatFromInt(config.BPM)) / 60.0;
    var chokes: usize = 0;
    for (notes, 0..) |open, i| {
        if (open.note.voice != .open_hihat or open.bar >= 8) continue;
        for (notes[i + 1 ..]) |closed| {
            if (closed.note.voice != .closed_hihat) continue;
            if (beats(closed) - beats(open) < ring_beats) chokes += 1;
            break;
        }
    }
    try std.testing.expect(chokes >= 8);
}

test "ghost-note section has quiet snares under the accents" {
    var ghosts: usize = 0;
    for (phrase(.snare).notes) |n| {
        if (n.bar >= 8 and n.bar < 16 and n.note.velocity < 0.3) ghosts += 1;
    }
    try std.testing.expect(ghosts >= 50);
}

test {
    std.testing.refAllDecls(@This());
}
