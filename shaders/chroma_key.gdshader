shader_type canvas_item;

// Vuelve transparente cualquier pixel parecido a "key_color" (por defecto
// negro), tipo pantalla verde. Sirve para el logo que viene con fondo negro
// solido y asi se puede poner sobre cualquier fondo sin caja negra alrededor.

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.15;
uniform float smoothness : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float diff = distance(tex.rgb, key_color.rgb);
	tex.a *= smoothstep(threshold, threshold + smoothness, diff);
	COLOR = tex;
}
