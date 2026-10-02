# pulse

A drum-solo music built by github.com/haruki7049/lightmix

A 24-bar drum solo at 190 BPM in 4/4 (about 30 seconds), rendered to a 44.1 kHz / 16-bit / stereo WAV file.

## Structure

| Bars | Section |
| :--- | :--- |
| 1–8 | Driving groove with open/closed hi-hat choke work |
| 9–16 | Snare ghost notes under syncopated snare and kick accents |
| 17–24 | Sextuplet tom fills, alternating kick/snare 16ths, a 32nd-note snare roll, and a final hit on the downbeat of bar 24 followed by a break |

The kit is one `resonator.Instrument` with four lanes. Each lane is monophonic, so a new hit cuts the previous one
on the same lane with a short micro-fade:

| Lane | Voices |
| :--- | :--- |
| 0 | Kick |
| 1 | Snare |
| 2 | Closed and open hi-hat (a closed hat chokes a ringing open hat) |
| 3 | High, mid and floor tom |

## Building

```sh
# Render zig-out/share/pulse.wav
zig build

# Render and play it
zig build play

# Run unit tests
zig build test
```

Requires Zig `0.16.0` (`nix develop` or `direnv allow` provides it).

## Releases

Pushing a tag that starts with `v` (e.g. `git tag v0.1.0 && git push origin v0.1.0`) runs `.github/workflows/release.yml`.
The workflow renders `pulse.wav` with `nix build` and attaches it, together with `SHA256SUMS`, to the GitHub Release
for that tag.

## Source layout

| File | Contents |
| :--- | :--- |
| `src/config.zig` | Tempo, meter, length and audio format |
| `src/kit.zig` | Drum voices, their lanes, and timbrefolio synthesis settings |
| `src/pattern.zig` | The score, written directly in Zig |
| `src/song.zig` | Places the score on a sequencer and renders, pads and normalizes the mix |
| `src/root.zig` | `gen` entry point used by `lightmix.addWave` |

## Dependencies

[`timbrefolio`](https://github.com/haruki7049/timbrefolio) (drum sounds),
[`sequencer`](https://github.com/haruki7049/sequencer),
[`resonator`](https://github.com/haruki7049/resonator),
[`phrases`](https://github.com/haruki7049/phrases) and
[`lightmix`](https://github.com/haruki7049/lightmix) 0.26.0. All of them resolve to a single `lightmix` and a single
`phrases` package. A unit test checks this.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or [MIT license](LICENSE-MIT) at your option.
