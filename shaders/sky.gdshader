shader_type sky;
render_mode use_debanding;

// The sky: a vertical gradient, a sun disc with a halo, and a field of stars.
//
// Every colour arrives as a uniform rather than being computed here. The
// shader knows how to *draw* a sky and nothing about what time it is --
// SkyGradient decides that on the CPU, where it can be tested with numbers
// instead of by looking at a screenshot.
//
// Sky shaders run once per pixel of the sky *and* again into the radiance
// cubemap that lights the world. AT_CUBEMAP_PASS separates the two: detail
// finer than the cubemap's texels does not survive being averaged into it, and
// stars sampled at that resolution shimmer through the ambient light of the
// whole scene.

// Direction *toward* the sun, not the direction its light travels.
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

group_uniforms colours;
uniform vec3 zenith_color : source_color = vec3(0.13, 0.33, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.95);
uniform vec3 ground_color : source_color = vec3(0.13, 0.12, 0.11);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 halo_color : source_color = vec3(1.0, 0.72, 0.42);

group_uniforms shape;
// Higher values keep the horizon band low and tight, which is what makes a sky
// read as deep rather than as a two-colour ramp.
uniform float horizon_falloff : hint_range(1.0, 12.0) = 4.0;
// Angular radius in radians. The real sun is 0.0047; a game sun that small is
// a pixel nobody notices.
uniform float sun_angular_radius : hint_range(0.002, 0.3) = 0.028;
uniform float sun_softness : hint_range(0.0005, 0.1) = 0.006;
uniform float sun_energy : hint_range(0.0, 200.0) = 26.0;
uniform float halo_strength : hint_range(0.0, 8.0) = 1.4;
uniform float halo_falloff : hint_range(1.0, 400.0) = 90.0;

group_uniforms stars;
// 0 in daylight, 1 at full night. The whole star field rides on this.
uniform float star_fade : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(20.0, 800.0) = 260.0;
uniform float star_brightness : hint_range(0.0, 8.0) = 1.6;
// Fraction of cells that hold no star. Higher is emptier sky.
uniform float star_sparsity : hint_range(0.0, 0.999) = 0.955;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.7;


vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}


// One candidate star per cell of a cube lattice, placed at a random point
// inside its own cell. A direction lands in exactly one cell, so the field is
// stable as the camera turns -- stars that swim when you look around are worse
// than no stars.
float star_field(vec3 direction, float time) {
	vec3 p = direction * star_density;
	vec3 cell = floor(p);
	vec3 random = hash33(cell);
	if (random.z < star_sparsity) {
		return 0.0;
	}

	float distance_to_star = length(fract(p) - random);
	// Wide enough to survive being resolved at 1080p. Narrower and each star
	// lands between pixels and reads as a night sky with nothing in it.
	float core = smoothstep(0.14, 0.0, distance_to_star);
	// Brightness varies per star, and each twinkles out of step with the rest.
	float magnitude = 0.35 + 0.65 * random.x;
	float twinkle = 0.75 + 0.25 * sin(time * twinkle_speed + random.y * 6.2831853);
	return core * magnitude * twinkle;
}


void sky() {
	vec3 direction = normalize(EYEDIR);
	float height = direction.y;

	// Curved rather than linear, so the interesting colour sits near the
	// horizon where the eye expects it.
	float up = pow(clamp(height, 0.0, 1.0), 1.0 / horizon_falloff);
	vec3 colour = mix(horizon_color, zenith_color, up);
	// A long fade, not a line. A short one draws a dark band across the view
	// exactly where the terrain tile runs out, which reads as a hole rather
	// than as distance.
	colour = mix(ground_color, colour, smoothstep(-0.45, 0.02, height));

	if (star_fade > 0.001 && !AT_CUBEMAP_PASS) {
		float above = smoothstep(-0.02, 0.09, height);
		colour += vec3(star_field(direction, TIME) * star_brightness * star_fade * above);
	}

	vec3 to_sun = normalize(sun_direction);
	float cosine = dot(direction, to_sun);

	// The disc is clipped at the horizon rather than fading out, which is what
	// makes a setting sun read as sinking *behind* something.
	float horizon_mask = smoothstep(-0.015, 0.02, height) * smoothstep(-0.06, 0.02, to_sun.y);
	float angle = acos(clamp(cosine, -1.0, 1.0));
	float disc = 1.0 - smoothstep(sun_angular_radius, sun_angular_radius + sun_softness, angle);

	colour += halo_color * pow(max(cosine, 0.0), halo_falloff) * halo_strength * horizon_mask;
	colour += sun_color * disc * sun_energy * horizon_mask;

	COLOR = colour;
}
