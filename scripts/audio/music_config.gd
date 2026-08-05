class_name MusicConfig
extends Resource
## Tuning for the generated background music.
##
## The music is synthesised rather than shipped as a file. That is a deliberate
## trade: a real composed track would sound better, and this has no licence to
## check, no megabytes in git, and no "where did this come from" in a year. It
## is a placeholder that knows it is one -- but it is a placeholder with knobs,
## and the knobs are here rather than scattered through the synthesiser.

## Samples per second. 22050 is half CD rate: inaudible for slow sine voices
## and half the work to generate.
@export_range(8000, 48000, 1) var sample_rate: int = 22050

## Length of the loop, in bars. Long enough not to nag, short enough that
## generating it is not a load screen.
@export_range(1, 32, 1) var bars: int = 8

@export_range(2, 8, 1) var beats_per_bar: int = 4

## Slow. This is something to not notice, not something to tap along to.
@export_range(20.0, 200.0, 1.0) var tempo_bpm: float = 56.0

## MIDI note the scale is built from. 45 is A2.
@export_range(24, 72, 1) var root_note: int = 45

## Semitone offsets from the root. Minor pentatonic by default: it has no
## semitone clashes, so any two notes played together are consonant, which is
## most of why generated music usually sounds wrong.
@export var scale: PackedInt32Array = PackedInt32Array([0, 3, 5, 7, 10])

## Chance of a melody note landing on any given beat. Below 1 the line breathes
## instead of marching.
@export_range(0.0, 1.0, 0.05) var note_density: float = 0.55

@export_group("Mix")
## The sustained root underneath everything.
@export_range(0.0, 1.0, 0.01) var drone_level: float = 0.16

## The chord that changes once a bar.
@export_range(0.0, 1.0, 0.01) var pad_level: float = 0.13

## The melody on top.
@export_range(0.0, 1.0, 0.01) var melody_level: float = 0.1

## Overall trim, applied last. The master volume setting is on top of this.
@export_range(0.0, 1.0, 0.01) var gain: float = 0.7

@export_group("Shape")
## Seconds a melody note takes to reach full volume. Slow is what makes it a
## pad rather than a bell.
@export_range(0.005, 2.0, 0.005) var attack_seconds: float = 0.09

## Seconds a melody note takes to fade out.
@export_range(0.05, 8.0, 0.05) var release_seconds: float = 1.4

@export var noise_seed: int = 8172


## Seconds in one beat.
func beat_seconds() -> float:
	return 60.0 / maxf(tempo_bpm, 1.0)


## Total beats in the loop.
func beat_count() -> int:
	return bars * beats_per_bar


## Seconds in the whole loop.
func loop_seconds() -> float:
	return beat_count() * beat_seconds()


## Samples in the whole loop.
func frame_count() -> int:
	return int(round(loop_seconds() * sample_rate))
