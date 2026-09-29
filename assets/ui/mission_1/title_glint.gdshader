shader_type canvas_item;
uniform float sweep = -1.0;
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float band = (1.0-smoothstep(0.0,0.035,abs(UV.x+UV.y*0.14-sweep))) * 0.22;
	COLOR = vec4(vec3(1.0,0.83,0.48),ink.a*band) * COLOR;
}
