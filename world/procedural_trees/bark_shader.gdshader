shader_type spatial;
render_mode cull_back;

uniform sampler2D bark_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 bark_color : source_color = vec4(0.34, 0.23, 0.15, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.90;
uniform float specular : hint_range(0.0, 1.0) = 0.15;
uniform bool use_texture = true;

varying vec2 v_bark_uv;

void vertex() {
	// UV.x: 0.0 a 1.0 alrededor de la circunferencia
	// UV.y: 0.0 a 1.0 a lo largo del segmento
	// INSTANCE_CUSTOM.r: Desfase horizontal aleatorio (rotacion aleatoria del patron)
	// INSTANCE_CUSTOM.g: Desfase vertical acumulado continuo a lo largo del tronco/rama
	// INSTANCE_CUSTOM.b: Factor de repeticion vertical de este segmento en metros
	vec2 base_uv = UV;
	
	if (INSTANCE_CUSTOM.b > 0.001) {
		v_bark_uv = vec2(
			base_uv.x + INSTANCE_CUSTOM.r,
			INSTANCE_CUSTOM.g + base_uv.y * INSTANCE_CUSTOM.b
		);
	} else {
		v_bark_uv = base_uv;
	}
}

void fragment() {
	if (use_texture) {
		vec4 tex = texture(bark_texture, v_bark_uv);
		ALBEDO = tex.rgb * bark_color.rgb;
	} else {
		ALBEDO = bark_color.rgb;
	}
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
