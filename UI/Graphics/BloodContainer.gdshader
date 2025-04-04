shader_type canvas_item;

uniform float front_back_offset = 0.5;
uniform sampler2D drop_mask;

uniform float smoothed_blood = 0.0; // Blood fill (smoothed in GDScript)

uniform float wave_frequency = 3.5; // Sine wave frequency
uniform float max_amplitude = 0.18; // Max amplitude of waves
uniform float wave_speed = 0.3; // Wave movement speed
uniform float pixel_size = 4.0;

// Function to pixelate UV coordinates
vec2 pixelate(vec2 uv, float size) {
    return floor(uv / size) * size;
}

// Function to generate procedural mask
vec4 mask_sample(vec2 uv, float blood_ratio) {
    // Apply pixelation
	vec2 pixel_uv = pixelate(uv, 1.0/960.0*pixel_size);

    // Calculate amplitude based on blood_ratio
    float amplitude = max_amplitude * (1.0 - 4.0 * pow(blood_ratio - 0.5, 2.0));

    // Clamp amplitude to avoid excessive values
    amplitude = clamp(amplitude, 0.0, max_amplitude);

	float step_size = 1.0/540.0*pixel_size;
    // Generate sine wave with animation
    float sine_offset = sin(pixel_uv.x * wave_frequency + TIME * wave_speed) * ceil(amplitude/step_size)*step_size/10.0;

    // Calculate threshold for masking
    float threshold = smoothed_blood + ceil(sine_offset / step_size) * step_size;

    // Step function for mask
    float mask_value = step(1.0 - uv.y, threshold);

    return vec4(vec3(mask_value), 1.0);
}

void fragment() {

    // UV offsets for parallax effect
    vec2 uvfront = vec2(UV.x + TIME * wave_speed, UV.y);
    vec2 uvback = vec2(UV.x - TIME * wave_speed + front_back_offset, UV.y + wave_speed / 100.0);

    // Sample procedural mask
    vec4 drop_mask_color = texture(drop_mask, UV);
    vec4 noise_front = mask_sample(uvfront, smoothed_blood);
    vec4 noise_back = mask_sample(uvback, smoothed_blood);

    // Define blood colors
    vec4 back_blood_color = vec4(0.4, 0.0, 0.0, noise_back.r * drop_mask_color.r);
    vec4 front_blood_color = vec4(0.6, 0.0, 0.0, noise_front.r * drop_mask_color.r);

    // Blend front and back layers
    vec4 final_color = front_blood_color;
    final_color.rgb = mix(back_blood_color.rgb, front_blood_color.rgb, front_blood_color.a);
    final_color.a = max(front_blood_color.a, back_blood_color.a);

    // Output final color
    COLOR = final_color;
}
