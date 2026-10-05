shader_type spatial;
render_mode unshaded;

// Cheap animated lava: two scrolling value-noise layers mixed into a fire gradient.

uniform vec3 hot : source_color = vec3(1.0, 0.72, 0.2);
uniform vec3 mid : source_color = vec3(0.8, 0.22, 0.03);
uniform vec3 cool : source_color = vec3(0.22, 0.03, 0.02);
uniform float scale = 0.18;
uniform float speed = 0.08;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * scale;
	float n = noise(p + vec2(TIME * speed, TIME * speed * 0.6));
	n = n * 0.6 + noise(p * 2.3 - vec2(TIME * speed * 1.3, 0.0)) * 0.4;
	vec3 c = mix(cool, mid, smoothstep(0.35, 0.65, n));
	c = mix(c, hot, smoothstep(0.7, 0.85, n));
	ALBEDO = c * 1.15;
}
