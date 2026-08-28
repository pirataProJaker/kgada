shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting, cull_disabled;

// PSX-style vertex snapping ("geometry wobble"). Emulates the original
// PlayStation's lack of sub-pixel vertex precision (no floating point
// transforms in hardware). As a side effect, UVs attached to the snapped
// vertices "swim" every frame, which approximates the classic PS1 texture
// warping look.
//
// Note: true affine texture mapping (disabling perspective-correct UV
// interpolation per-pixel) is NOT possible in Godot's shading language -
// it only exposes `flat` / `smooth` (default) interpolation qualifiers for
// varyings, not `noperspective` like raw GLSL/HLSL. This vertex snap is the
// closest authentic-feeling approximation without a much more complex
// manual barycentric UV hack.
uniform int grid_precision = 40; // lower = more wobble/jitter, higher = smoother
uniform vec4 albedo_color : source_color = vec4(0.8, 0.8, 0.85, 1.0);

// Optional texture, triplanar-mapped (no UVs needed - works for Marching
// Cubes terrain too). Defaults to plain white (hint_default_white), so if
// nothing is assigned the result is just `albedo_color` as a solid color -
// drop a texture onto this parameter later and it multiplies in on top.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform float texture_scale : hint_range(0.01, 4.0) = 0.25;

// Gradiente de color por altura (opcional, apagado por defecto para no
// afectar materiales existentes como las cajas). El terreno lo activa para
// pintar llanuras de verde, roca de montana en gris, y picos nevados en
// blanco - una progresion de 3 tonos en vez de un mezcla directa de 2.
uniform bool use_height_gradient = false;
uniform vec4 low_color : source_color = vec4(0.3, 0.5, 0.25, 1.0);
uniform vec4 mid_color : source_color = vec4(0.45, 0.43, 0.4, 1.0);
uniform vec4 high_color : source_color = vec4(0.92, 0.94, 0.97, 1.0);
uniform float gradient_low_height = 14.0;
uniform float gradient_mid_height = 24.0;
uniform float gradient_high_height = 32.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap to a low-resolution grid in normalized device coordinates.
	float grid = float(max(grid_precision, 1));
	clip_position.xyz /= clip_position.w;
	clip_position.xy = floor(clip_position.xy * grid) / grid;
	clip_position.xyz *= clip_position.w;

	POSITION = clip_position;

	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Triplanar blend: sample the texture from the 3 world axes and blend
	// by how much the surface normal faces each one. Avoids needing real
	// UV coordinates, which Marching Cubes meshes don't have.
	vec3 blend = abs(world_normal);
	blend /= (blend.x + blend.y + blend.z);

	vec3 sample_pos = world_position * texture_scale;
	vec4 tex_x = texture(albedo_texture, sample_pos.yz);
	vec4 tex_y = texture(albedo_texture, sample_pos.xz);
	vec4 tex_z = texture(albedo_texture, sample_pos.xy);
	vec4 tex_color = tex_x * blend.x + tex_y * blend.y + tex_z * blend.z;

	vec3 base_color = albedo_color.rgb;
	if (use_height_gradient) {
		if (world_position.y < gradient_mid_height) {
			float t = smoothstep(gradient_low_height, gradient_mid_height, world_position.y);
			base_color = mix(low_color.rgb, mid_color.rgb, t);
		} else {
			float t = smoothstep(gradient_mid_height, gradient_high_height, world_position.y);
			base_color = mix(mid_color.rgb, high_color.rgb, t);
		}
	}

	ALBEDO = tex_color.rgb * base_color;
	ROUGHNESS = 1.0;
}

