shader_type spatial;
render_mode cull_disabled;

// Grass, shrubs and trees. Shares its shading with everything else through the
// same include the terrain and the characters use -- a field lit by its own
// maths sits on the ground rather than in it.
//
// Culling is disabled for the whole family. Crossed quads have no meaningful
// front, and a stylised trunk seen from inside is not a thing anyone will look
// at; in exchange, an entire class of "the mesh built fine and is invisible"
// bug stops being possible. That trap is in CLAUDE.md and it has cost this
// project time before.

#include "res://shaders/stylised.gdshaderinc"

group_uniforms surface;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;

// The value band is applied when the mesh is built, not here. Grass sits in the
// GROUND band -- it is what a character is read against, so a meadow in its own
// brighter band would undo the silhouette Phase 2 was spent buying -- but the
// whole gradient has to move together, and a per-pixel band lands the root and
// the tip on the same value. See FoliageMesh.for_layer.

group_uniforms shading;
uniform float ramp_softness : hint_range(0.01, 0.5) = 0.22;
uniform float ramp_lift : hint_range(0.0, 1.0) = 0.1;

group_uniforms wind;
// How far a tip travels, in metres.
uniform float sway : hint_range(0.0, 2.0) = 0.09;
uniform float sway_speed : hint_range(0.0, 4.0) = 0.9;
// Metres per wave. Long, so a field moves in gusts rather than shimmering.
uniform float gust_length : hint_range(1.0, 80.0) = 14.0;

void vertex() {
	// UV.y is the sway weight, 0 at the root and 1 at the tip -- see
	// FoliageMesh. Squared, so the bend is a curve rather than a shear: a blade
	// hinges near its base and the top travels furthest.
	float weight = UV.y * UV.y;

	// Phase from the instance's own world position, so neighbouring clumps move
	// together and the field reads as wind crossing it rather than as every
	// blade waving on its own.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = (origin.x + origin.z) / gust_length;
	float t = TIME * sway_speed;

	// Two waves at different rates, which is the cheapest way to stop a field
	// looking like it is breathing in time.
	float bend = sin(t + phase) * 0.65 + sin(t * 1.7 + phase * 2.3) * 0.35;

	// Applied in world space and then brought back, so a rotated instance bends
	// with the wind rather than with its own facing.
	vec3 offset = vec3(bend, 0.0, bend * 0.4) * sway * weight;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
}


void fragment() {
	// COLOR is the root-to-tip gradient baked into the mesh. No texture at all:
	// there is no artist, and a gradient in the vertices is what a stylised
	// plant actually needs.
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.05;
	// NORMAL is deliberately left alone. Writing a world-space normal here --
	// which the first version did -- overrides the one Godot has already
	// flipped for back faces, so with culling off every second face of every
	// crossed quad renders as though it faced away from the sun. It shows up as
	// solid black blobs under the trees and reads as a shadow bug.
}


// ALBEDO is applied by the compositor, never here -- see stylised.gdshader.
void light() {
	float shade = stylised_ramp(dot(normalize(NORMAL), normalize(LIGHT)), ramp_softness, ramp_lift);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade;
}
