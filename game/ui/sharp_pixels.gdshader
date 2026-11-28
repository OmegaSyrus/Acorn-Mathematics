// Sharp pixels (art grid plan 2026-11-24). The tablet shows 1 design unit as
// about 1.48 screen pixels, so plain nearest sampling draws art pixels 1 or 2
// screen pixels wide at random and the grid looks uneven. This samples each
// art pixel as a flat square and blends only the one screen pixel on its edge,
// so every art pixel comes out the same size at any screen scale. When art is
// drawn smaller than 1:1 (the half-size crossing) it falls back to smooth
// linear sampling, which is what that view used before.
// Needs the texture filter set to linear (project default).
shader_type canvas_item;

// COLOR in fragment() already holds texture x modulate, so keep the modulate here.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * size;
	vec2 w = max(fwidth(p), vec2(1e-4));
	// blend texel i into i+1 only across the one screen pixel where they meet
	vec2 c = p - 0.5;
	vec2 sharp = floor(c) + 0.5 + clamp((fract(c) - 0.5) / w + 0.5, 0.0, 1.0);
	vec2 q = mix(sharp, p, step(vec2(1.0), w));
	COLOR = texture(TEXTURE, q / size) * modulate;
}
