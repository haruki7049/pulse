const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const lightmix = b.dependency("lightmix", .{});
    const phrases = b.dependency("phrases", .{ .target = target, .optimize = optimize });
    const resonator = b.dependency("resonator", .{ .target = target, .optimize = optimize });
    const sequencer = b.dependency("sequencer", .{ .target = target, .optimize = optimize });
    const timbrefolio = b.dependency("timbrefolio", .{ .target = target, .optimize = optimize });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
            .{ .name = "phrases", .module = phrases.module("phrases") },
            .{ .name = "resonator", .module = resonator.module("resonator") },
            .{ .name = "sequencer", .module = sequencer.module("sequencer") },
            .{ .name = "timbrefolio", .module = timbrefolio.module("timbrefolio") },
        },
    });

    // `zig build` renders the drum solo into zig-out/share/pulse.wav
    const wave = try l.addWave(b, mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .name = "pulse.wav",
        } },
    });
    l.installWave(b, wave);

    const play_step = b.step("play", "Play the generated pulse.wav");
    const play = try l.addPlay(b, wave, .{});
    play_step.dependOn(&play.step);

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
}
