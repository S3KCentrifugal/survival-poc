shader_type spatial;

// Shares its shading with everything else in the game. Before this the terrain
// was the only surface in the world drawn with its own lighting, which is the
// quickest way to make a world look like two worlds.
#include "res://shaders/stylised.gdshaderinc"

// Ground textured by what the ground is doing: grass where it is flat, rock
// where it is steep, dirt in between.
//
// Slope-driven rather than painted. There is no splat map, no vertex colours
// and nothing for an artist to keep in sync with the heightfield -- regenerate
// the terrain with a different seed and the texturing follows, because it is
// derived from the same surface. The cost is that it cannot express "a path
// here", which is a thing to want later and not today.
//
// Cliffs are sampled triplanar. A steep face UV-mapped from above is the
// texture smeared into vertical streaks, which is the single most obvious tell
// that a terrain is untextured rather than textured badly.

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;

group_uniforms tiling;
// Metres per repeat. Small numbers tile visibly; large ones turn to mush.
uniform float grass_scale : hint_range(0.5, 40.0) = 3.5;
uniform float dirt_scale : hint_range(0.5, 40.0) = 4.5;
uniform float rock_scale : hint_range(0.5, 40.0) = 6.0;

// A second sample of the grass at a different scale, mixed in to break the
// repeat. Two tilings of one texture beat one tiling of a better texture.
uniform float macro_scale : hint_range(4.0, 200.0) = 47.0;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.45;

group_uniforms blending;
// Surface angles, in degrees from flat, where each transition happens.
uniform float dirt_begins : hint_range(0.0, 90.0) = 16.0;
uniform float dirt_full : hint_range(0.0, 90.0) = 26.0;
uniform float rock_begins : hint_range(0.0, 90.0) = 32.0;
uniform float rock_full : hint_range(0.0, 90.0) = 46.0;

// Softens the slope thresholds with the surface's own detail, so the boundary
// between grass and rock is ragged rather than a contour line.
uniform float edge_noise : hint_range(0.0, 1.0) = 0.35;

group_uniforms tint;
uniform vec3 grass_tint : source_color = vec3(0.78, 0.92, 0.66);
uniform vec3 dirt_tint : source_color = vec3(0.95, 0.88, 0.76);
uniform vec3 rock_tint : source_color = vec3(0.88, 0.88, 0.9);
uniform float terrain_roughness : hint_range(0.0, 1.0) = 0.92;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.8;

group_uniforms value_band;
// ART.md rule 3. The ground is the floor of the value structure and the thing
// every character is read against, so this is the more important half of the
// contrast: pulling the ground down separates it from the actors standing on
// it far more cheaply than pushing the actors up, which clips and desaturates.
uniform float band_value : hint_range(0.0, 1.0) = 0.06;
uniform float band_strength : hint_range(0.0, 1.0) = 0.85;

group_uniforms shading;
uniform float ramp_softness : hint_range(0.01, 0.5) = 0.22;
uniform float ramp_lift : hint_range(0.0, 1.0) = 0.1;

varying vec3 world_position;
varying vec3 world_normal;


// Samples a texture from three directions and blends by the surface normal, so
// a vertical face is textured by the two axes that actually face outward.
vec4 triplanar(sampler2D map, vec3 position, vec3 normal, float scale) {
	vec3 weights = pow(abs(normal), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec4 x_axis = texture(map, position.zy / scale);
	vec4 y_axis = texture(map, position.xz / scale);
	vec4 z_axis = texture(map, position.xy / scale);
	return x_axis * weights.x + y_axis * weights.y + z_axis * weights.z;
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec3 normal = normalize(world_normal);
	float slope = degrees(acos(clamp(normal.y, -1.0, 1.0)));

	// A cheap high-frequency value from the surface itself. Ragged edges cost
	// one texture lookup that was going to happen anyway.
	float jitter = (texture(dirt_albedo, world_position.xz * 0.05).r - 0.5) * edge_noise * 14.0;
	slope += jitter;

	// Flat ground, with a second much larger tiling mixed over it. One texture
	// repeating every 3.5 m is a chequerboard from any height; the same texture
	// also repeating every 47 m hides the grid without a second asset.
	vec4 grass = texture(grass_albedo, world_position.xz / grass_scale);
	vec4 macro = texture(grass_albedo, world_position.xz / macro_scale);
	grass = mix(grass, grass * macro * 2.0, macro_strength);
	vec3 grass_n = texture(grass_normal, world_position.xz / grass_scale).rgb;

	vec4 dirt = texture(dirt_albedo, world_position.xz / dirt_scale);
	vec3 dirt_n = texture(dirt_normal, world_position.xz / dirt_scale).rgb;

	vec4 rock = triplanar(rock_albedo, world_position, normal, rock_scale);
	vec3 rock_n = triplanar(rock_normal, world_position, normal, rock_scale).rgb;

	float to_dirt = smoothstep(dirt_begins, dirt_full, slope);
	float to_rock = smoothstep(rock_begins, rock_full, slope);

	vec3 albedo = mix(grass.rgb * grass_tint, dirt.rgb * dirt_tint, to_dirt);
	albedo = mix(albedo, rock.rgb * rock_tint, to_rock);

	vec3 mapped = mix(mix(grass_n, dirt_n, to_dirt), rock_n, to_rock);

	ALBEDO = stylised_to_band(albedo, band_value, band_strength);
	NORMAL_MAP = mapped;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = terrain_roughness;
	SPECULAR = 0.15;
}


// The same ramp every other surface uses. ALBEDO is applied by the compositor,
// not here -- see shaders/stylised.gdshader.
void light() {
	float shade = stylised_ramp(dot(normalize(NORMAL), normalize(LIGHT)), ramp_softness, ramp_lift);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade;
}
