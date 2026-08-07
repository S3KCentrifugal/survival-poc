// The shading every surface in the game shares.
//
// Included by stylised.gdshader (characters, structures, props) and by
// terrain.gdshader. One copy, so a change to the look is a change in one file
// rather than a change everyone has to remember to make twice -- the same
// argument UiTokens makes for the interface, one layer down.
//
// The numbers all come from ArtTokens through uniforms. Nothing is typed in
// here; see ART.md rule 8.

const vec3 STYLISED_LUMA = vec3(0.2126, 0.7152, 0.0722);


float stylised_luminance(vec3 colour) {
	return max(dot(colour, STYLISED_LUMA), 0.0001);
}


// Pulls a colour toward a target brightness, keeping its hue.
//
// This is ART.md rule 3 -- "a character sits at least 3:1 in luminance against
// what is immediately behind them" -- as an operation. The project measured
// 1.0-1.2:1 in every shot because the robot's albedo happens to sit at almost
// exactly the luminance of grass, of the building walls and of the floor. No
// amount of lighting fixes that; it is what the surfaces *are*.
//
// So each kind of surface is assigned a band and pulled into it. Ground sits
// low, characters sit high, and the gap between the two bands is the silhouette.
//
// Scaled rather than lerped toward grey, so a saturated green stays a saturated
// green and only its brightness moves. Lerping toward the target as a colour
// would desaturate everything into a uniform sludge, which is the other way to
// fail rule 1.
//
// NOTE: SurfacePalette.to_band() is the same formula in GDScript, for flat
// colours and for the tests. If you change one, change both.
vec3 stylised_to_band(vec3 albedo, float target, float amount) {
	float level = stylised_luminance(albedo);
	return clamp(mix(albedo, albedo * (target / level), amount), vec3(0.0), vec3(1.0));
}


// A soft three-step ramp, not a cel band.
//
// ART.md is painterly rather than cel-shaded, so the steps are wide enough to
// read as a soft terminator and only the *distribution* of light is stylised:
// more of the surface sits in the mid band than Lambert would put there, which
// is what makes a shape read as a shape rather than as a gradient.
//
// `lift` is the floor -- how lit the darkest facing is before ambient. Never
// zero: a surface facing directly away from the sun is still lit by the sky,
// and rule 4 says that is the whole reason shadows are blue.
float stylised_ramp(float n_dot_l, float softness, float lift) {
	float level = clamp(n_dot_l, 0.0, 1.0);
	float low = smoothstep(0.0, max(softness, 0.001), level);
	float mid = smoothstep(0.45 - softness, 0.45 + softness, level);
	float high = smoothstep(0.80 - softness, 0.80 + softness, level);
	// Weighted so each plateau lands near the Lambert value it replaces:
	// 0.22 at the terminator, 0.55 through the middle, 1.0 facing the sun. The
	// first attempt gave the lowest band 0.45, which lit any surface even
	// slightly turned toward the sun at nearly half strength -- so every rolling
	// hill and every curved character came out pale and formless. A ramp is
	// allowed to quantise the light; it is not allowed to invent it.
	float shaped = low * 0.22 + mid * 0.33 + high * 0.45;
	return lift + (1.0 - lift) * shaped;
}


// How much of the rim is showing at this pixel.
//
// Fresnel against the view. ART.md rule 3 is explicit that this is an *edge*
// cue and not the fix for silhouette -- Phase 1 established that lighting
// cannot move a mass measurement -- but an edge cue is still worth having,
// because it is what keeps a character legible against a busy background at the
// moment the value bands happen to line up.
float stylised_rim(vec3 normal, vec3 view, float power) {
	float facing = clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0);
	return pow(1.0 - facing, max(power, 0.01));
}
