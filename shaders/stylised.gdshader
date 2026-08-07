shader_type spatial;

// Everything that is not the terrain or the sky: characters, walls, floors,
// props. One shader for all of them, which is the point -- surfaces drawn by
// different shaders never quite look like they belong to the same world, and
// "cohesion, not fidelity" is most of what ART.md is asking for.
//
// Built to be a drop-in for the StandardMaterial3D it replaces: it takes the
// same albedo colour and texture, so StylisedSurface can convert an imported
// glTF material without anybody hand-authoring anything.

#include "res://shaders/stylised.gdshaderinc"

group_uniforms surface;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo_texture = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.1;

group_uniforms value_band;
// ART.md rule 3. See stylised_to_band().
uniform float band_value : hint_range(0.0, 1.0) = 0.3;
uniform float band_strength : hint_range(0.0, 1.0) = 0.8;

group_uniforms shading;
uniform float ramp_softness : hint_range(0.01, 0.5) = 0.22;
uniform float ramp_lift : hint_range(0.0, 1.0) = 0.1;

group_uniforms rim;
uniform vec3 rim_color : source_color = vec3(0.7, 0.82, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.55;
uniform float rim_power : hint_range(0.5, 12.0) = 3.2;

varying vec3 view_normal;


void vertex() {
	view_normal = NORMAL;
}


void fragment() {
	vec4 surface = albedo;
	if (has_albedo_texture) {
		surface *= texture(albedo_texture, UV);
	}

	ALBEDO = stylised_to_band(surface.rgb, band_value, band_strength);
	// ALPHA is deliberately never written. Touching it at all switches the
	// material to the transparent pipeline, and transparent materials do not
	// cast shadows -- so every shadow in the game quietly disappeared and the
	// shadow pass dropped from ~190 draw calls to ~30, which reads as a
	// batching win rather than as a bug. Nothing errors. See devblog 045.
	ROUGHNESS = roughness;
	SPECULAR = specular_amount;

	// The rim is added as emission rather than accumulated in light(), on
	// purpose: a rim that only appears on the lit side vanishes exactly when it
	// is most needed, which is a character standing in shadow against a bright
	// background. Tinted toward the sky by default, because the thing physically
	// wrapping a silhouette out here is skylight -- rule 4 again.
	EMISSION = rim_color * stylised_rim(view_normal, VIEW, rim_power) * rim_strength;
}


// The shared ramp, in place of Lambert.
//
// ALBEDO must NOT be multiplied in here. Godot applies it to DIFFUSE_LIGHT
// itself, and doing it again squares it: the surface goes darker and its
// contrast against the background drops, while still looking broadly plausible.
// Checked rather than assumed, because the docs' Lambert example is ambiguous
// on the point -- see devblog 045.
void light() {
	float shade = stylised_ramp(dot(normalize(NORMAL), normalize(LIGHT)), ramp_softness, ramp_lift);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade;
}
