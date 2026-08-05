class_name SkyConfig
extends Resource
## What the sky looks like at each part of the day.
##
## Three palettes -- night, dawn/dusk, day -- and the numbers that draw the sun.
## [SkyGradient] blends between them; nothing here knows about time, only about
## how high the sun is.

@export_group("Day")
@export var day_zenith: Color = Color(0.09, 0.29, 0.72)
@export var day_horizon: Color = Color(0.68, 0.83, 0.96)

@export_group("Dawn and dusk")
## The band the sun passes through at sunrise and sunset is the same geometry
## in both directions, so it is one palette rather than two.
@export var dusk_zenith: Color = Color(0.16, 0.19, 0.45)
@export var dusk_horizon: Color = Color(1.0, 0.48, 0.22)

## How far above and below the horizon, as a fraction of straight up, the dusk
## palette still applies. Wider makes longer, more gradual sunsets.
@export_range(0.02, 0.6, 0.01) var dusk_band: float = 0.16

@export_group("Night")
@export var night_zenith: Color = Color(0.015, 0.025, 0.075)
@export var night_horizon: Color = Color(0.05, 0.07, 0.14)

## How much darker than the horizon everything below it is, 0 unchanged and 1
## black.
##
## A fraction rather than a colour on purpose. A fixed grey down there is an
## unrelated shade sitting under a sky that changes all day, and where the
## terrain tile ends it reads as a hole in the world rather than as distance.
@export_range(0.0, 1.0, 0.01) var ground_darkening: float = 0.45

@export_group("Sun")
@export var sun_high_color: Color = Color(1.0, 0.97, 0.9)

## What the disc turns as it reaches the horizon. The atmosphere is thicker
## along that path, and this is the cheap version of saying so.
@export var sun_low_color: Color = Color(1.0, 0.55, 0.25)

@export var halo_color: Color = Color(1.0, 0.7, 0.4)

## Angular radius in radians. The real sun is 0.0047, which is a pixel.
@export_range(0.002, 0.3, 0.001) var sun_angular_radius: float = 0.028

@export_range(0.0, 200.0, 0.5) var sun_energy: float = 26.0

## Peak halo, reached at the horizon where the sun's light travels furthest
## through the air.
@export_range(0.0, 8.0, 0.05) var halo_strength: float = 1.6

@export_group("Stars")
@export_range(0.0, 8.0, 0.05) var star_brightness: float = 1.6

## Fraction of the sky's cells with no star in them. Higher is emptier.
@export_range(0.0, 0.999, 0.001) var star_sparsity: float = 0.955

@export_range(20.0, 800.0, 5.0) var star_density: float = 260.0

@export_group("Blending")
## Elevation, as a fraction of straight up, above which the day palette applies
## in full. Matches [member DayNightConfig.twilight_band] by default so the sky
## and the sunlight change together.
@export_range(0.05, 1.0, 0.01) var twilight_band: float = 0.25
