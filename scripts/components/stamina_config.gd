class_name StaminaConfig
extends Resource
## Tuning for an actor's capacity for effort.
##
## The three rates set the rhythm of a chase: how long you can run, how long you
## must walk afterwards, and how severely running dry is punished.

## Maximum stamina, in the same arbitrary units as the rates below.
@export_range(1.0, 1000.0, 1.0) var maximum: float = 100.0

## Cost per second of sustained effort. At the defaults a full bar buys five
## seconds of sprinting.
@export_range(0.1, 200.0, 0.1) var drain_per_second: float = 20.0

## Refill per second once recovery has started.
@export_range(0.1, 200.0, 0.1) var recovery_per_second: float = 15.0

## Quiet seconds after spending before recovery begins.
##
## Without a delay, tapping the sprint key is free: the bar refills in the gaps
## between taps and the actor sprints indefinitely at a stutter.
@export_range(0.0, 10.0, 0.05) var recovery_delay: float = 1.0

## After running the bar dry, this fraction must be back before effort is
## allowed again.
##
## Zero would let an exhausted actor spend one frame in every two, which reads
## as a bug rather than as exhaustion.
@export_range(0.0, 1.0, 0.01) var exhausted_recovery_fraction: float = 0.25
