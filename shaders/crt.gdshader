shader_type canvas_item;
// CRT TV look, drawn over the whole game as a post-process overlay.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float curvature = 0.07;      // barrel distortion
uniform float scanline_strength = 0.28;
uniform float scanline_period = 3.0; // screen pixels per scanline
uniform float mask_strength = 0.10;  // RGB phosphor stripes
uniform float aberration = 1.3;      // colour fringing, in screen pixels
uniform float vignette = 0.45;
uniform float flicker = 0.012;
uniform float brightness = 1.14;     // makes up for the darkening above
uniform float corner = 0.035;        // rounded tube corners

vec2 bend(vec2 uv) {
	vec2 c = uv - 0.5;
	float d = dot(c, c);
	return uv + c * d * curvature * 4.0;
}

void fragment() {
	vec2 uv = bend(SCREEN_UV);
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 screen = 1.0 / px;

	// Outside the tube: black bezel.
	vec2 edge = min(uv, 1.0 - uv);
	float tube = smoothstep(0.0, corner * 0.35, min(edge.x, edge.y));
	vec2 q = max(vec2(corner) - edge, 0.0);
	tube *= 1.0 - smoothstep(corner * 0.8, corner, length(q));

	vec2 off = vec2(px.x * aberration, 0.0);
	vec2 cuv = clamp(uv, vec2(0.0), vec2(1.0));
	vec3 col;
	col.r = texture(screen_tex, cuv + off).r;
	col.g = texture(screen_tex, cuv).g;
	col.b = texture(screen_tex, cuv - off).b;

	// Soft glow: a cheap blur from a lower mip, added on top.
	vec3 glow = textureLod(screen_tex, cuv, 2.5).rgb;
	col += glow * glow * 0.35;

	// Scanlines.
	float line = 0.5 + 0.5 * cos(uv.y * screen.y * 6.2831853 / scanline_period);
	col *= 1.0 - scanline_strength * (1.0 - line);

	// Aperture grille.
	int stripe = int(mod(FRAGCOORD.x, 3.0));
	vec3 mask = vec3(1.0 - mask_strength);
	if (stripe == 0) { mask.r = 1.0; } else if (stripe == 1) { mask.g = 1.0; } else { mask.b = 1.0; }
	col *= mask;

	// Vignette and flicker.
	vec2 v = uv - 0.5;
	col *= 1.0 - vignette * dot(v, v) * 2.2;
	col *= 1.0 + flicker * sin(TIME * 110.0) + flicker * 0.5 * sin(TIME * 7.0);
	// Faint rolling bar.
	col *= 1.0 + 0.025 * smoothstep(0.0, 0.08, 0.08 - abs(fract(uv.y - TIME * 0.07) - 0.5));

	COLOR = vec4(col * brightness * tube, 1.0);
}
