//! pulse: a 24-bar drum solo at 190 BPM.
//!
//! The score (`pattern.zig`) is placed on a four-lane `resonator.Instrument` drum kit inside a
//! `sequencer.Sequencer`, voiced with timbrefolio drums (`kit.zig`), and rendered by lightmix.
//! `zig build` turns `gen` into `zig-out/share/pulse.wav`.

const std = @import("std");
const lightmix = @import("lightmix");
const config = @import("./config.zig");
const song = @import("./song.zig");

/// Entry point used by `lightmix.addWave` to generate `pulse.wav`.
pub fn gen(init: std.process.Init) !lightmix.Wave(config.T) {
    return song.render(init.arena.allocator());
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("./config.zig");
    _ = @import("./kit.zig");
    _ = @import("./pattern.zig");
    _ = @import("./song.zig");
}

test "dependencies share one phrases, resonator and lightmix" {
    const phrases = @import("phrases");
    const resonator = @import("resonator");
    const sequencer = @import("sequencer");
    try std.testing.expect(sequencer.Instrument == resonator.Instrument);
    try std.testing.expect(resonator.phrases.Position == phrases.Position);
    try std.testing.expect(@FieldType(sequencer.Event(config.T), "wave") == lightmix.Wave(config.T));
}
