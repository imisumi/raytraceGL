#version 330

// #define DEBUG_COLOR
out vec4 fragColor;
uniform float exposure;

uniform sampler2D screenTexture;
uniform vec2 resolution;

uniform int samples;

void main()
{
	vec3 op = texture(screenTexture, gl_FragCoord.xy / resolution.xy).rgb;
	op = op / samples;
	// fragColor = vec4(pow(exposure * op, vec3(1.0 / 2.2)), 1);
	fragColor = vec4(pow(op, vec3(1.0 / 2.2)), 1);
	// fragColor = vec4(op, 1.0);
}
